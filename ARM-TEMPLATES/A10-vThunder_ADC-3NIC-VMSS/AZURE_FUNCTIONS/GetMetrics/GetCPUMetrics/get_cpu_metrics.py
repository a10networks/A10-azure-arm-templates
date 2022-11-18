"""
Script to get vThunder instances CPU Usage data on per minute basis and store in a variable
 in automation account.

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

    @staticmethod
    def get_vth_auth_token(baseurl):
        """
        Return vthunder instance authentication token for AXAPI.
        :param baseurl:
        :return auth_token:
        """
        payload = json.dumps({
            "credentials": {
                "username": "admin",
                "password": "a10"
            }
        })
        headers = {
            'Content-Type': 'application/json'
        }
        url = baseurl + '/auth'
        try:
            response = requests.request("POST", url, headers=headers, data=payload, verify=False)
            response = response.json()
            auth_token = 'A10 ' + response['authresponse']['signature']
            return auth_token
        except Exception as exp:
            logging.error(exp)
            return None


class GetMetricData:
    @staticmethod
    def get_data_cpu_usage(baseurl, auth_token):
        """
        Get vthunder instance last 1 minute data CPU usage.
        :param baseurl:
        :param auth_token:
        :return:
        """
        url = baseurl + '/system-cpu/data-cpu/oper'
        headers = {
            'Authorization': auth_token
        }
        payload = {}
        try:
            response = requests.request("GET", url, headers=headers, data=payload, verify=False)
            cpu_usage_list = response.json()['data-cpu']['oper']['cpu-usage']

            total_cpu_usage = 0
            for cpu_usage in cpu_usage_list:
                total_cpu_usage += cpu_usage['60-sec']
            return total_cpu_usage/len(cpu_usage_list)

        except Exception as exp:
            logging.error(exp)
            return 0


class VMSSvThunders:
    @staticmethod
    def list_vmss_vthunders_ips(client, resource_group_name, automation_account_name):
        automation_variable = 'vThunderIP'
        vth_ips = client.variable.get(resource_group_name, automation_account_name, automation_variable)
        vth_ips = json.loads(vth_ips.value)
        if isinstance(vth_ips, str):
            if 'null' in vth_ips:
                vth_ips = vth_ips.replace('null', '"null"')
            vth_ips = ast.literal_eval(vth_ips)
        return vth_ips


def handle():
    logging.info('Executing GetMetric function')    
    # load env variables
    load_dotenv(".env")
    auth = Authentication()
    # get azure credentials
    credential = auth.get_azure_cred()

    # gat subscription id value
    subscription_id = os.getenv("SubscriptionId")

    # create automation account client
    automation_client = AutomationClient(credential=credential, subscription_id=subscription_id)

    # get values
    resource_group_name = os.getenv("ResourceGroupName")
    cpu_variable_name = 'vCPUUsage'
    automation_account = os.getenv("AutomationAccName")

    # get vmss vthunder instances ips
    vmss = VMSSvThunders()
    vth_ips = vmss.list_vmss_vthunders_ips(client=automation_client,
                                           resource_group_name=resource_group_name,
                                           automation_account_name=automation_account)

    # get CPU usage of each vthunder
    vmss_total_cpu_uage = 0
    get_cpu_usage = GetMetricData()
    for ip in vth_ips:
        try:
            baseurl = 'https://'+ip+'/axapi/v3'
            auth_token = auth.get_vth_auth_token(baseurl=baseurl)
            cpu_usage = get_cpu_usage.get_data_cpu_usage(baseurl, auth_token)
            vmss_total_cpu_uage += cpu_usage
        except Exception as exp:
            logging.error(exp)

    # get vmss cpu average
    if len(vth_ips):
        vmss_avg_cpu_uage = vmss_total_cpu_uage/len(vth_ips)
    else:
        vmss_avg_cpu_uage = vmss_total_cpu_uage

    # get current avg cpu
    last_cpu_usage = automation_client.variable.get(resource_group_name=resource_group_name,
                                                    automation_account_name=automation_account,
                                                    variable_name=cpu_variable_name)

    # convert string into json object
    last_cpu_usage = last_cpu_usage.value
    last_cpu_usage = json.loads(last_cpu_usage)
    if isinstance(last_cpu_usage, str):
        last_cpu_usage = ast.literal_eval(last_cpu_usage)

    # delete older than 5 minute avg cpu data from automation account variable
    for timestamp in list(last_cpu_usage):
        date = datetime.fromtimestamp(int(timestamp))
        if date < datetime.utcnow()-timedelta(minutes=10):
            del last_cpu_usage[timestamp]

    # insert avg cpu data from automation account variable
    dtime = datetime.utcnow()
    unixtime = time.mktime(dtime.timetuple())
    last_cpu_usage.update({str(int(unixtime)): vmss_avg_cpu_uage})
    last_cpu_usage = json.dumps(last_cpu_usage)
    # automation_client.variable.update()
    automation_client.variable.update(resource_group_name, automation_account, cpu_variable_name,
                                        {
                                            "name": cpu_variable_name,
                                            "value": last_cpu_usage,
                                            "description": "last 5 minute cpu usage",
                                            "is_encrypted": False
                                        }
                                        )
    logging.info('Updated automation account at %s' % datetime.utcnow())
