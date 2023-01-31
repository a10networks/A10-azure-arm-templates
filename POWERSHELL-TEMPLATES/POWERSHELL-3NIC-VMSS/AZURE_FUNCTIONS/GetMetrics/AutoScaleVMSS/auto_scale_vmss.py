"""
Script to scale-in or scale-out VMSS containing vThunder instances based on last 5 minute
 average CPU Usage data.

author: Vikas Gautam
author email: vgautam@a10networks.com
"""


import logging
import os
import requests
import json
import time
import ast
from dotenv import load_dotenv
from datetime import datetime, timedelta

from azure.mgmt.compute import ComputeManagementClient
from azure.identity import DefaultAzureCredential
from azure.mgmt.automation import AutomationClient

import warnings
warnings.filterwarnings("ignore")


class Authentication:
    @staticmethod
    def get_azure_cred():
        """
        Get azure credential object using service app environment variable.
        :return credential:
        """
        # Acquire a credential object
        token_credential = DefaultAzureCredential()
        return token_credential


class VMSSScaleing:
    @staticmethod
    def get_vmss_capacity(client, resource_group_name, vthunder_scale_set):
        """
        This function will return the old capacity of virtual machine scale-set
        :param client:
        :param resource_group_name:
        :param vthunder_scale_set:
        :return capcity:
        """
        try:
            cap = client.virtual_machine_scale_sets.get(resource_group_name=resource_group_name,
                                                        vm_scale_set_name=vthunder_scale_set)
            return cap.__dict__['sku'].__dict__['capacity']
        except Exception as exp:
            logging.error(exp)
            return None

    @staticmethod
    def vmss_scale_out(client, old_capacity, resource_group_name, vthunder_scale_set):
        """
        This function to scale out VMSS by increasing the capacity by 1.
        :param client:
        :param old_capacity:
        :param resource_group_name:
        :param vthunder_scale_set:
        :return:
        """
        instance_increase = 1
        new_capacity = old_capacity + instance_increase
        client.virtual_machine_scale_sets.begin_update(resource_group_name=resource_group_name,
                                                               vm_scale_set_name=vthunder_scale_set,
                                                               parameters={'sku': {'capacity': new_capacity}})

    @staticmethod
    def vmss_scale_in(client, old_capacity, resource_group_name, vthunder_scale_set):
        """
        This function to scale in VMSS by decreasing the capacity by 1.
        :param client:
        :param old_capacity:
        :param resource_group_name:
        :param vthunder_scale_set:
        :return:
        """
        instance_decrease = 1
        new_capacity = old_capacity - instance_decrease
        client.virtual_machine_scale_sets.begin_update(resource_group_name=resource_group_name,
                                                               vm_scale_set_name=vthunder_scale_set,
                                                               parameters={'sku': {'capacity': new_capacity}})

    @staticmethod
    def webhook_call(master_webhook_url):
        """
        Function to call webhook url
        :param master_webhook_url:
        :return:
        """
        try:
            payload = {}
            headers = {}
            requests.request("POST", master_webhook_url, headers=headers, data=payload, verify=False)
        except Exception as exp:
            logging.error(exp)


def handle():
    # load env variables
    load_dotenv(".env")
    # gat subscription id value
    subscription_id = os.getenv("SubscriptionId")
    resource_group_name = os.getenv("ResourceGroupName")
    automation_account = os.getenv("AutomationAccName")
    
    # automation account variables
    azure_auto_scale_resources_variable = 'azureAutoScaleResources'
    auto_scale_param_variable = 'autoScaleParam'
    cpu_variable_name = 'vCPUUsage'

    auth = Authentication()
    # get azure credentials
    credential = auth.get_azure_cred()

    # create compute account client
    compute_client = ComputeManagementClient(credential=credential, subscription_id=subscription_id)
    # create automation account client
    automation_client = AutomationClient(credential=credential, subscription_id=subscription_id)

    # get azure auto scale automation account variable value
    azure_auto_scale_resources = automation_client.variable.get(resource_group_name=resource_group_name,
                                                    automation_account_name=automation_account,
                                                    variable_name=azure_auto_scale_resources_variable)

    azure_auto_scale_resources = azure_auto_scale_resources.value
    azure_auto_scale_resources = json.loads(azure_auto_scale_resources)
    if isinstance(azure_auto_scale_resources, str):
        azure_auto_scale_resources = ast.literal_eval(azure_auto_scale_resources)

    # get vthunder vmss name
    vthunder_scale_set = azure_auto_scale_resources['vThunderScaleSetName']
    # get master runbook webhook url
    master_webhook_url = azure_auto_scale_resources['masterWebhookUrl']

    # get autoScaleParam automation account variable value
    auto_scale_param = automation_client.variable.get(resource_group_name=resource_group_name,
                                                      automation_account_name=automation_account,
                                                      variable_name=auto_scale_param_variable)

    # convert string to json object
    auto_scale_param = auto_scale_param.value
    auto_scale_param = json.loads(auto_scale_param)
    if isinstance(auto_scale_param, str):
        auto_scale_param = ast.literal_eval(auto_scale_param)

    # get scaling thresholds
    scaleout_threshold = auto_scale_param['scaleOutThreshold']
    scalein_threshold = auto_scale_param['scaleInThreshold']
    max_scale_out_limit = auto_scale_param['maxScaleOutLimit']
    min_scale_in_limit = auto_scale_param['minScaleInLimit']

    # check if scaleout threshold < scalein threshold
    if scaleout_threshold <= scalein_threshold:
        logging.error('Scaleout threshold: %s value is less than scale in threshold:% s'
                      % (scaleout_threshold, scalein_threshold))
        return

    # get current avg cpu
    last_cpu_usage = automation_client.variable.get(resource_group_name=resource_group_name,
                                                    automation_account_name=automation_account,
                                                    variable_name=cpu_variable_name)

    last_cpu_usage = last_cpu_usage.value
    last_cpu_usage = json.loads(last_cpu_usage)
    if isinstance(last_cpu_usage, str):
        last_cpu_usage = ast.literal_eval(last_cpu_usage)

    # check last 5 minute average CPU usage
    total_average_cpu = 0
    count = 0
    for timestamp in last_cpu_usage:
        date = datetime.fromtimestamp(int(timestamp))
        if datetime.utcnow()-timedelta(minutes=5) <= date <= datetime.utcnow():
            total_average_cpu += last_cpu_usage[timestamp]
            count += 1
    try:
        total_average_cpu = total_average_cpu/count
        logging.info('vmss avg cpu in last %s minute: %s' % (count, total_average_cpu))
    except ZeroDivisionError as exp:
        logging.info('last 5 minute timestmap data is missing.')
        logging.exception(exp)

    # check last 5 minute cpu usage
    if count < 5:
        logging.info('insufficient data, found only last: %s minutes data' % count)
        return

    # check current capacity of VMSS
    scale = VMSSScaleing()
    current_capacity = scale.get_vmss_capacity(client=compute_client,
                                               resource_group_name=resource_group_name,
                                               vthunder_scale_set=vthunder_scale_set)

    # check scale out condition
    if total_average_cpu > scaleout_threshold:
        if current_capacity >= max_scale_out_limit:
            logging.warning('max scale out limit reached, aborting scale out')
            logging.info('max scale out limit: %s' % max_scale_out_limit)
        else:
            # scale out vmss
            logging.debug('Scaling out')
            logging.debug({'total_average_cpu': total_average_cpu,
                           'scaleout_threshold': scaleout_threshold})
            scale.vmss_scale_out(client=compute_client, old_capacity=current_capacity,
                                 resource_group_name=resource_group_name,
                                 vthunder_scale_set=vthunder_scale_set)

            logging.debug('Executing Master Runbook')
            scale.webhook_call(master_webhook_url=master_webhook_url)

    # check scale in condition
    if total_average_cpu < scalein_threshold:
        if current_capacity <= min_scale_in_limit:
            logging.warning('min scale in limit reached, aborting scale in.')
            logging.info('max scale in limit: %s' % min_scale_in_limit)
        else:
            # scale in vmss
            logging.debug('Scaling In VMSS')
            logging.debug({'total average cpu': total_average_cpu,
                           'scale in threshold': scaleout_threshold})
            scale.vmss_scale_in(client=compute_client,
                                old_capacity=current_capacity,
                                resource_group_name=resource_group_name,
                                vthunder_scale_set=vthunder_scale_set)

            logging.debug('Executing Master Runbook')
            scale.webhook_call(master_webhook_url=master_webhook_url)
