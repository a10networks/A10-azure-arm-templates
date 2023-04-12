#!/usr/bin/python
# -*- coding: UTF-8 -*-

# Copyright 2023 A10 Networks
# GNU General Public License v3.0+
# (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
# 
# Python script to change password for thunders. Script will apply new password as per user's input.
# Script will prompt to provide input of thunder device and apply new password to thunder.
import warnings
import json
import getpass
import sys
import requests
warnings.filterwarnings('ignore')


class VthunderPasswordHandler:
    def __init__(self):
        self.public_ip = None

    def get_auth_token(self, password, username):
        """
        Function to get authorization token.
        :param password: password of thunder
        :param username: thunder's username
        # :param public_ip: thunder public ip
        :return: Authorization token
        AXAPI: /axapi/v3/auth
        """
        # AXAPI header
        headers = {
            "accept": "application/json",
            "Content-Type": "application/json"
        }
        # AXAPI Auth url json body
        data = {"credentials": {
            "username": username,
            "password": password
        }
        }
        base_url = "https://{0}/axapi/v3".format(self.public_ip)
        url = "".join([base_url, "/auth"])
        try:
            response = requests.post(url, headers=headers,
                                     data=json.dumps(data), verify=False, timeout=10)
            if response.status_code != 200:
                print(response.text)
                print("Failed to get auth token from thunder. Please provide valid credentials or unable to connect "
                      "thunder host.")
                return None
            else:
                authorization_token = json.loads(response.text)["authresponse"]["signature"]
                return authorization_token
        except Exception as exp:
            print("Failed to get auth token from thunder. Please provide valid credentials or unable to connect "
                  "thunder host.")
            print(exp)
            return None

    def write_memory(self, authorization_token):
        """
        Function to save configurations on active partition
        :param authorization_token: authorization token
        :return:
        AXAPI: /axapi/v3/active-partition
        AXAPI: /axapi/v3//write/memory
        """
        headers = {
            "Authorization": "".join(["A10 ", authorization_token]),
            "accept": "application/json",
            "Content-Type": "application/json"
        }
        base_url = "https://{0}/axapi/v3".format(self.public_ip)
        url = "".join([base_url, "/active-partition"])

        response = requests.get(url, headers=headers, verify=False, timeout=10)
        partition = json.loads(response.text)['active-partition']['partition-name']

        if partition is None:
            sys.exit("Failed to get partition name. Please try again")
        else:
            url = "".join([base_url, "/write/memory"])
            data = {
                "memory": {
                    "partition": partition
                }
            }
            try:
                response = requests.post(url, headers=headers,
                                         data=json.dumps(data), verify=False, timeout=10)
                if response.status_code != 200:
                    print(response.text)
                    sys.exit("Failed to write memory. Please try again.")
                else:
                    print("Password change configurations saved on partition: " + partition)
            except Exception as exp:
                print(exp)
                sys.exit("Failed to write memory. Please try again.")

    def changed_admin_password(self, username, thunder_ip, vth_old_password, vth_new_password):
        """
        Function for changing admin password
        AXAPI: /admin/{admin-user}/password
        :param username: thunder's username
        :param thunder_ip: public ip of thunder
        :param vth_old_password: thunder's Old Password
        :param vth_new_password: thunder's New password
        """
        self.public_ip = thunder_ip
        base_url = "https://{0}/axapi/v3".format(self.public_ip)
        auth_token = self.get_auth_token(vth_old_password, username)
        if not auth_token:
            return False

        url = ''.join([base_url, "/admin/admin/password"])
        headers = {
            "accept": "application/json",
            "Authorization": "".join(["A10 ", auth_token]),
            "Content-Type": "application/json"
        }
        data = {
            "password": {
                "password-in-module": vth_new_password
            }
        }
        try:
            response = requests.post(url, headers=headers, data=json.dumps(data), verify=False, timeout=10)
            if response.status_code != 200:
                print(
                    "Failed to apply new password. Please provide valid credentials or unable to connect thunder host.")
                print(response.text)
                return False
            else:
                auth_token = self.get_auth_token(vth_new_password, username)
                self.write_memory(auth_token)
                return True
        except Exception as exp:
            print("Failed to apply new password. Please provide valid credentials or unable to connect thunder host.")
            print(exp)
            return False


# driver code
if __name__ == "__main__":

    change_password = VthunderPasswordHandler()
    print("Primary conditions for password validation, user should provide the new password according to the "
          "given combination: \n \nMinimum length of 9 characters \nMinimum lowercase character should be 1 \n"
          "Minimum uppercase character should be 1 \nMinimum number should be 1 \nMinimum special character "
          "should be 1 \nShould not include repeated characters \nShould not include more than 3 keyboard "
          "consecutive characters.\n")
    print(
        "------------------------------------------------------------------------------------------------")
    status = False
    while not status:
        vTh_public_ip = input("Enter thunder host/ip: ")
        user_name = input("Enter thunder username: ")
        vTh_old_password = getpass.getpass(prompt="Enter thunder current password for %s: " % vTh_public_ip)
        vTh_new_password1 = getpass.getpass(prompt="Enter thunder new password: ")
        vTh_new_password2 = getpass.getpass(prompt="Confirm new password: ")
        if vTh_new_password1 == vTh_new_password2:
            status = change_password.changed_admin_password(user_name, vTh_public_ip, vTh_old_password,
                                                            vTh_new_password1)
            if status:
                print("Password successfully changed for: %s" % vTh_public_ip)
                print(
                    "------------------------------------------------------------------------------------------------")
                choice = input("Do you want to continue(Y/N).")
                if choice in ('Y', 'y'):
                    status = False
                else:
                    status = True
            else:
                continue
        else:
            print("Password does not match. Please try again.")
            continue
