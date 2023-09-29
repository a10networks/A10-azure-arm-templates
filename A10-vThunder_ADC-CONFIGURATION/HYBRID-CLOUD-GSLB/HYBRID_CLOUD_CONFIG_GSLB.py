# importing the module
import json
import requests
import os.path
from LOGGER import logger
import warnings


warnings.filterwarnings('ignore')

# HYBRID_CLOUD_CONFIG_GSLB_PARAM.json contains slb configurable parameters
with open('HYBRID_CLOUD_CONFIG_GSLB_PARAM.json') as json_file:
    slb_param_data = json.load(json_file)


def get_auth_token(username, password, base_url):
    """
    Function to get authorization token.
    :param username: username for vthunder instance
    :param password: password of vthunder
    :param base_url: vthunder base url to access axapi
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
    url = "".join([base_url, "/auth"])
    try:
        response = requests.post(url, headers=headers,
                                 data=json.dumps(data), verify=False)
        if response.status_code != 200:
            logger.error('Failed to get authorization token from AXAPI')
            logger.error(response.text)
        else:
            authorization_token = json.loads(response.text)["authresponse"]["signature"]
            return authorization_token
    except Exception as e:
        logger.error('Error in authentication token: ', exc_info=True)


def configure_ethernets(base_url, authorization_token):
    """
        This function will configure ethernet
        :param base_url: vthunder base url to access axapi
        :param authorization_token: authorization token
        AXAPI: /interface/ethernet/<ethernet_number>
        :return:
    """

    # AXAPI interface url headers
    header = {
        "Authorization": "".join(["A10 ", authorization_token]),
        "accept": "application/json",
        "Content-Type": "application/json"
    }
    # for each private ip address and add configuration in ethernet list
    ethernet_number = 1
    while ethernet_number <3:
        # AXAPI ethernets Url
        url = "".join([base_url, "/interface/ethernet/" + str(ethernet_number)])
        body = {
            "ethernet": {
                "ifnum": ethernet_number,
                "action": "enable",
                "ip": {
                    "dhcp": 1
                }
            }
        }
        # Invoke interface AXAPI
        try:
            response = requests.post(
                url, headers=header, data=json.dumps(body), verify=False)
            if response.status_code != 200:
                logger.error("Failed to configure ethernet- " + str(ethernet_number) + " ip")
                logger.error(response.text)
            else:
                logger.info("configured ethernet- " + str(ethernet_number) + " ip")
                print("configured ethernet- " + str(ethernet_number) + " ip")
            # increase ethernet number by 1
            ethernet_number += 1

        except Exception as e:
            logger.error('Error in configuring ethernet: ', exc_info=True)


def configure_server(slb_param_data, base_url, authorization_token, count, site_name, servers_pvt_ips, servers):
    """
    Function to configure server
    :param slb_param_data: parameters loaded from parameter file.
    :param base_url: Base url of AXAPI
    :param authorization_token: authorization token
    :param count: count of vm
    :param site_name: site name
    : param servers_pvt_ips: private ips list of servers
    :param: servers : servers name list

    :return:
    AXAPI: /axapi/v3/slb/server
    """
    headers = {
        "Authorization": "".join(["A10 ", authorization_token]),
        "accept": "application/json",
        "Content-Type": "application/json"
    }
    print("Configuring slb server for site: " + site_name)
    slb_server_port_list = "slbServerPortList" + str(count)
    ports = slb_param_data["parameters"][slb_server_port_list]["value"]
    server_name = servers[count - 1]
    host_name = servers_pvt_ips[count - 1]
    server_details = {"name": server_name, 'host': host_name, 'port-list': ports, 'health-check-disable': 1}
    body = {"server": server_details}
    url = "".join([base_url, "/slb/server"])
    try:
        response = requests.post(url, headers=headers,
                                 data=json.dumps(body), verify=False)
        if response.status_code != 200:
            logger.error("Failed to configure slb server for site: " + site_name)
            logger.error(response.text)
        else:
            logger.info("Successfully Configured slb server for site: " + site_name)
            print("Successfully Configured slb server for site: " + site_name)
    except Exception as e:
        logger.error('Error in configuring server: ', exc_info=True)


def configure_service_group(slb_param_data, base_url, authorization_token, count, site_name, servers):
    """
    Function to configure service group
    :param slb_param_data: parameters loaded from parameter file.
    :param base_url: Base url of AXAPI
    :param authorization_token: authorization token
    :param count: count of vm
    :param site_name: vThunder name
    :param :servers : servers list
    :return:
    AXAPI: /axapi/v3/slb/service-group
    """
    headers = {
        "Authorization": "".join(["A10 ", authorization_token]),
        "accept": "application/json",
        "Content-Type": "application/json"
    }
    url = "".join([base_url, "/slb/service-group"])
    print("Configuring service group for site: " + site_name)
    service_group_list = "serviceGroupList" + str(count)
    service_groups = slb_param_data["parameters"][service_group_list]["value"]
    service_groups[0]["member-list"][0]["name"] = servers[count - 1]
    body = {
        "service-group-list": service_groups
    }
    try:
        response = requests.post(url, headers=headers,
                                 data=json.dumps(body), verify=False)
        if response.status_code != 200:
            logger.error("Failed to configure service group for site:" + site_name)
            logger.error(response.text)
        else:
            logger.info("Successfully Configured service group for site:" + site_name)
            print("Successfully Configured service group for site:" + site_name)
    except Exception as e:
        logger.error('Error in configuring service group: ', exc_info=True)


def configure_virtual_server(slb_param_data, base_url, authorization_token, count, site_name, vm_second_ip):
    """
    Function to configure virtual servers
    :param slb_param_data: parameters loaded from parameter file.
    :param base_url: Base url of AXAPI
    :param authorization_token: authorization token
    :param count: count of vm
    :param site_name: site device name
    :param vm_second_ip: secondary ip of vm
    :return:
    AXAPI: /axapi/v3/slb/virtual-server
    """
    headers = {
        "Authorization": "".join(["A10 ", authorization_token]),
        "accept": "application/json",
        "Content-Type": "application/json"
    }
    url = "".join([base_url, "/slb/virtual-server"])

    virtual_server_list = "virtualServerList" + str(count)
    virtual_server_ports = slb_param_data["parameters"][virtual_server_list]["value"]
    virtual_server = {
        "name": slb_param_data["parameters"][virtual_server_list]['virtual-server-name'],
        "ip-address": vm_second_ip,
        "port-list": virtual_server_ports
    }
    virtual_server_list = [virtual_server]
    data = {
        "virtual-server-list": virtual_server_list
    }
    try:
        response = requests.post(url, headers=headers,
                                 data=json.dumps(data), verify=False)
        if response.status_code != 200:
            logger.error("Failed to configure virtual server for site: " + site_name)
            logger.error(response.text)
        else:
            logger.info("Successfully Configured virtual server for site: " + site_name)
            print("Successfully Configured virtual server for site: " + site_name)
    except Exception as e:
        logger.error('Error in configuring virtual servers: ', exc_info=True)


def configure_site_device(base_url, authorization_token, site_name):
    """
         Function to configure site device
        :param base_url: Base url of AXAPI
        :param authorization_token: authorization token
        :param site_name: site device name
        :return:
        AXAPI: /axapi/v3/gslb/protocol/enable
        example:
        gslb protocol enable device
        """
    url = "".join([base_url, "/gslb/protocol/enable"])
    headers = {
        "Authorization": "".join(["A10 ", authorization_token]),
        "accept": "application/json",
        "Content-Type": "application/json"
    }
    site_device = {
        "type": "device"
    }
    body = {
        "enable-list": [site_device]
    }
    try:
        response = requests.post(url, headers=headers,
                                 data=json.dumps(body), verify=False)
        if response.status_code != 200:
            logger.error("Failed to configure gslb site device")
            logger.error(response.text)
        else:
            logger.info("Successfully Configured gslb site: " + site_name)
            print("Successfully Configured gslb site: " + site_name)
    except Exception as e:
        logger.error('Error in configuring virtual servers: ', exc_info=True)


def configure_default_route(base_url, authorization_token, site_name, rib_list):
    """
         Function to configure default route
        :param base_url: Base url of AXAPI
        :param authorization_token: authorization token
        :param site_name: site name
        :param rib_list: default routes
        :return:
        AXAPI: /axapi/v3/ip/route/rib

        This function configures defualt route on all the devices(sites and controllers)
        This is needed for the traffic exiting the vthunder
        example:
        ip route 0.0.0.0 /0 10.2.1.1
        """
    url = "".join([base_url, "/ip/route/rib"])
    headers = {
        "Authorization": "".join(["A10 ", authorization_token]),
        "accept": "application/json",
        "Content-Type": "application/json"
    }

    body = {
        "rib-list": rib_list
    }
    try:
        response = requests.post(url, headers=headers,
                                 data=json.dumps(body), verify=False)
        if response.status_code != 200:
            logger.error("Failed to configure default route " + site_name)
            logger.error(response.text)
        else:
            logger.info("Successfully Configured default route:" + site_name)
            print("Successfully Configured default route:" + site_name)
    except Exception as e:
        logger.error('Error in configuring default route: ', exc_info=True)


def configure_service_ip(slb_param_data, base_url, authorization_token, controller_name, site_sec_ips, site_sec_pub_ips):
    """
        Function to configure service ip
        :param slb_param_data: parameters loaded from parameter file.
        :param base_url: Base url of AXAPI
        :param authorization_token: authorization token
        :param controller_name: controller name
        :param vm_private_ips: private ips of site device
        :param site_sec_pub_ips: secondary public ips of site device
        :return:
        AXAPI: /axapi/v3/gslb/service-ip

        This function configures service ip for controllers
        vmpublicip will have the public ip addresses for secondary data interfaces-client side of site devices
        public ips will be configured as external-ips in the configuration on controllers
        vmprivate ip contains the private ip addresses of the secondary data interfaces-client side of site devices
        These private ip addresses would be the virtual server ipaddresses on site devices
        The remaining values needed for configuring the service-ip are obtained from slb_param file
        example:
        gslb service-ip vs3 10.26.1.8
            external-ip 20.110.220.204
            port 80 tcp
        """
    url = "".join([base_url, "/gslb/service-ip"])
    headers = {
        "accept": "application/json",
        "Authorization": "".join(["A10 ", authorization_token]),
        "Content-Type": "application/json"
    }
    for i in range(4):
        service_ip_list_info = "serviceipList" + str((i + 1))

        service_ip_ports = slb_param_data["parameters"][service_ip_list_info]["value"]
        service_ip = {"node-name": slb_param_data["parameters"][service_ip_list_info]['node-name'],
                      "ip-address": site_sec_ips[i], "external-ip": site_sec_pub_ips[i],
                      "port-list": service_ip_ports}
        service_ip_list = [service_ip]
        body = {
            "service-ip-list": service_ip_list
        }
        try:
            response = requests.post(url, headers=headers,
                                     data=json.dumps(body), verify=False)
            if response.status_code != 200:
                logger.error("Failed to configure ServiceIp for site: " + controller_name)
                logger.error(response.text)
            else:
                logger.info("Successfully Configured ServiceIp for site: " + controller_name)
                print("Successfully Configured ServiceIp for site: " + controller_name)
        except Exception as e:
            logger.error('Error in configuring ServiceIp: ', exc_info=True)


def configure_site(site_public_ips, base_url, authorization_token, controller_name):
    """
        Function to configure site
        :param site_public_ips: public ips of site devices.
        :param base_url: Base url of AXAPI
        :param authorization_token: authorization token
        :param controller_name: vm's controller name

        :return:
        AXAPI: /axapi/v3/gslb/site

        This function configures gslb sites on the controllers
        mgmt_sites contains the management interfaces names of site devices
        vm_management_publicip will have the public ip addresses for the management interface of site devices
        the remaining information is obtained from the slb param file
        example:
        gslb site east_2
            geo-location "North America"
            slb-dev slb2 52.249.195.137
                vip-server vs2
            """
    url = "".join([base_url, "/gslb/site"])

    headers = {
        "accept": "application/json",
        "Authorization": "".join(["A10 ", authorization_token]),
        "Content-Type": "application/json"
    }
    # getting the public ip addresses of the management interfaces of site devices
    # vm_management_publicip will have the public ip addresses for the management interface of site devices
    for i in range(4):

        site_list_info = "siteList" + str((i + 1))
        vip_name = {
            "vip-name": slb_param_data["parameters"][site_list_info]["vip-name"]
        }
        vip_server_name_list = [vip_name]
        vip_server = {
            "vip-server-name-list": vip_server_name_list
        }
        slb_dev = {
            "device-name": slb_param_data["parameters"][site_list_info]["device-name"],
            "ip-address": site_public_ips[i][0],
            "vip-server": vip_server
        }

        slb_dev_list = [slb_dev]
        geo_location = {
            "geo-location": slb_param_data["parameters"][site_list_info]["geo-location"]
        }
        geolocation_list = [geo_location]
        site = {
            "site-name": slb_param_data["parameters"][site_list_info]["site-name"],
            "slb-dev-list": slb_dev_list,
            "multiple-geo-locations": geolocation_list
        }
        site_list = []
        site_list.append(site)
        body = {"site-list": site_list}
        try:
            response = requests.post(url, headers=headers,
                                     data=json.dumps(body), verify=False)
            if response.status_code != 200:
                logger.error("Failed to configure site information")
                logger.error(response.text)
            else:
                logger.info("Successfully Configured site information for: " + controller_name)
                print("Successfully Configured site information for: " + controller_name)
        except Exception as e:
            logger.error('Error in configuring site information: ', exc_info=True)


def configure_gslb_policy(slb_param_data, base_url, authorization_token, controller_name):
    """
        This function configures gslb policy on controller devices
        :param slb_param_data: parameters loaded from parameter file.
        :param base_url: vthunder base url to access axapi
        :param authorization_token: authorization token
        :param controller_name: vm's controller name
        :return:
        AXAPI: /axapi/v3/gslb/policy

        example:
        gslb policy a10
        metric-order geographic
        dns server
    """
    url = "".join([base_url, "/gslb/policy"])
    headers = {
        "accept": "application/json",
        "Authorization": "".join(["A10 ", authorization_token]),
        "Content-Type": "application/json"
    }
    dns = {
        "server": 1,
        "server-authoritative": 1
    }
    policy = {
        "name": slb_param_data["parameters"]["dnsPolicy"]["policy-name"],
        "metric-order": 1,
        "metric-type": slb_param_data["parameters"]["dnsPolicy"]["type"],
        "dns": dns
    }
    policy_list = [policy]
    body = {"policy-list": policy_list}
    try:
        response = requests.post(url, headers=headers,
                                 data=json.dumps(body), verify=False)
        if response.status_code != 200:
            logger.error("Failed to configure gslb policy")
            logger.error(response.text)
        else:
            logger.info("Successfully Configured gslb policy for :" + controller_name)
            print("Successfully Configured gslb policy for :" + controller_name)
    except Exception as e:
        logger.error('Error in configuring  gslb policy: ', exc_info=True)


def configure_gslb_zone(slb_param_data, base_url, authorization_token, controller_name):
    """
    Function to configure gslb zone
    :param slb_param_data: parameters loaded from parameter file.
    :param base_url: vthunder base url to access axapi
    :param authorization_token: authorization token
    :param controller_name: vm's controller name
    :return:
    AXAPI: /axapi/v3/gslb/zone

    This function configures gslb zone on controller
        The values are obtained from slb param file
        example:
        gslb zone gslb.a10.com
            policy a10
            service 80 www
                dns-a-record vs1 static
                dns-a-record vs2 static
                dns-a-record vs3 static
                dns-a-record vs4 static
    """

    url = "".join([base_url, "/gslb/zone"])
    headers = {
        "accept": "application/json",
        "Authorization": "".join(["A10 ", authorization_token]),
        "Content-Type": "application/json"
    }
    dnsarecordsrv = {
        "svrname": slb_param_data["parameters"]["serviceipList1"]["node-name"],
        "static": 1
    }
    dnsarecordsrvlist = [dnsarecordsrv]

    dnsarecordsrv = {
        "svrname": slb_param_data["parameters"]["serviceipList2"]["node-name"],
        "static": 1
    }
    dnsarecordsrvlist.append(dnsarecordsrv)

    dnsarecordsrv = {
        "svrname": slb_param_data["parameters"]["serviceipList3"]["node-name"],
        "static": 1
    }
    dnsarecordsrvlist.append(dnsarecordsrv)

    dnsarecordsrv = {
        "svrname": slb_param_data["parameters"]["serviceipList4"]["node-name"],
        "static": 1
    }
    dnsarecordsrvlist.append(dnsarecordsrv)
    dnsarecord = {
        "dns-a-record-srv-list": dnsarecordsrvlist
    }
    service = {
        "service-port": slb_param_data["parameters"]["gslbzone"]["service-port"],
        "service-name": slb_param_data["parameters"]["gslbzone"]["service-name"],
        "dns-a-record": dnsarecord
    }
    servicelist = [service]
    zone = {
        "name": slb_param_data["parameters"]["gslbzone"]["name"],
        "policy": slb_param_data["parameters"]["dnsPolicy"]["policy-name"],
        "service-list": servicelist
    }
    zonelist = [zone]

    body = {"zone-list": zonelist}

    try:
        response = requests.post(url, headers=headers,
                                 data=json.dumps(body), verify=False)
        if response.status_code != 200:
            logger.error("Failed to configure gslb zone")
            logger.error(response.text)
        else:
            logger.info("Successfully Configured gslb zone for :" + controller_name)
            print("Successfully Configured gslb zone for :" + controller_name)
    except Exception as e:
        logger.error('Error in configuring  gslb zone: ', exc_info=True)


def configure_gslb_server(slb_param_data, base_url, authorization_token, count, controller_name, controller_sec_ip):
    """
        Function to configure gslb server
        :param slb_param_data: parameters loaded from parameter file.
        :param base_url: vthunder base url to access axapi
        :param authorization_token: authorization token
        :param count: count of Virtual Server
        :param controller_name: vm's controller name
        :param controller_sec_ip: secondary ip of controller
        :return:
        AXAPI: /axapi/v3/slb/virtual-server

        This function configures gslb virtual server on the controllers
            example:
            slb virtual-server vip-server 10.20.1.5
                port 53 udp
                    gslb-enable
    """

    url = "".join([base_url, "/slb/virtual-server"])

    headers = {
        "accept": "application/json",
        "Authorization": "".join(["A10 ", authorization_token]),
        "Content-Type": "application/json"
    }
    gslb_server_list = "gslbserverList" + str(count)
    gslb_server_ports = slb_param_data["parameters"][gslb_server_list]["value"]

    gslb_server = {"name": slb_param_data["parameters"][gslb_server_list]["virtual-server-name"],
                   "ip-address": controller_sec_ip,
                   "port-list": gslb_server_ports}
    gslb_server_list = [gslb_server]
    body = {"virtual-server-list": gslb_server_list}
    try:
        response = requests.post(url, headers=headers,
                                 data=json.dumps(body), verify=False)

        if response.status_code != 200:
            logger.error("Failed to configure gslb server for controller")
            logger.error(response.text)
        else:
            logger.info("Successfully Configured gslb server for controller : " + controller_name)
            print("Successfully Configured gslb server for controller: " + controller_name)
    except Exception as e:
        logger.error('Error in configuring  gslb server: ', exc_info=True)


def configure_controller_and_status_interval(slb_param_data, base_url, authorization_token, controller_name):
    """
        Function to configure controller and status interval
        :param slb_param_data: parameters loaded from parameter file.
        :param base_url: vthunder base url to access axapi
        :param authorization_token: authorization token
        :param controller_name: vm's controller_name
        :return:
        AXAPI: /axapi/v3/slb/virtual-server

        This function configures status interval and enables controller function on controller devices

            example:
            gslb protocol status-interval 1
            gslb protocol enable controller
        """

    url = "".join([base_url, "/gslb/protocol"])
    headers = {
        "accept": "application/json",
        "Authorization": "".join(["A10 ", authorization_token]),
        "Content-Type": "application/json"
    }
    controller1 = {
        "type": "controller"
    }
    controllerlist = [controller1]
    protocol = {
        "enable-list": controllerlist,
        "status-interval": slb_param_data["parameters"]["gslbprotocolStatus"]["status-interval"]
    }
    body = {
        "protocol": protocol
    }

    try:
        response = requests.post(url, headers=headers,
                                 data=json.dumps(body), verify=False)
        if response.status_code != 200:
            logger.error("Failed to configure gslb controller")
            logger.error(response.text)
        else:
            logger.info("Successfully Configured gslb controller and status interval: " + controller_name)
            print("Successfully Configured gslb controller and status interval: " + controller_name)
    except Exception as e:
        logger.error('Error in configuring  gslb controller and status interval: ', exc_info=True)


def configure_controller_group(slb_param_data, base_url, authorization_token, count, controller_name, primaryip=0):
    """
    Function to configure gslb group
    :param slb_param_data: parameters loaded from parameter file.
    :param base_url: Base url of AXAPI
    :param authorization_token: authorization token
    :param controller_name: controller name  of controller
    :param count:count of controller group
    :param primaryip: primary ip address- this is the ip addresses of the other controller device
    :return:
    AXAPI: /axapi/v3/gslb/group

    example:
        gslb group default
            enable
            primary 20.22.200.39
            priority 255

    """
    url = "".join([base_url, "/gslb/group"])
    headers = {
        "accept": "application/json",
        "Authorization": "".join(["A10 ", authorization_token]),
        "Content-Type": "application/json"
    }

    primary = {
        "primary": primaryip
    }
    primary_list = [primary]

    gslbcontrollerGroup = "gslbcontrollerGroup" + str(count)
    if primaryip == 0:
        group = {
            "name": slb_param_data["parameters"][gslbcontrollerGroup]["name"],
            "priority": slb_param_data["parameters"][gslbcontrollerGroup]["priority"],
            "enable": 1
        }
    else:
        group = {
            "name": slb_param_data["parameters"][gslbcontrollerGroup]["name"],
            "priority": slb_param_data["parameters"][gslbcontrollerGroup]["priority"],
            "primary-list": primary_list,
            "enable": 1
        }
    grouplist = [group]
    body = {
        "group-list": grouplist
    }
    try:
        response = requests.post(url, headers=headers,
                                 data=json.dumps(body), verify=False)
        if response.status_code != 200:
            logger.error("Failed to configure gslb controller group")
            logger.error(response.text)
        else:
            logger.info("Successfully Configured gslb controller group: " + controller_name)
            print("Successfully Configured gslb controller group: " + controller_name)
    except Exception as e:
        logger.error('Error in configuring   gslb controller group: ', exc_info=True)


def enable_geo_location(slb_param_data, base_url, authorization_token, controller_name):
    """
    Function to enable geolocation
    :param slb_param_data: parameters loaded from parameter file.
    :param base_url: Base url of AXAPI
    :param authorization_token: authorization token
    :param controller_name: controller name
    :return:
    AXAPI: /axapi/v3/system
	This function enables geo location on controller devices
	example:
	no system geo-location load iana
	system geo-location load GeoLite2-Country
    """

    url = "".join([base_url, "/system"])
    headers = {
        "Authorization": "".join(["A10 ", authorization_token]),
        "accept": "application/json",
        "Content-Type": "application/json"
    }

    geolocation = {
        "geo-location-iana": slb_param_data["parameters"]["geolocation"]['geo-location-iana'],
        "geo-location-geolite2-city": slb_param_data["parameters"]["geolocation"]['geo-location-geolite2-city'],
        "geolite2-city-include-ipv6": slb_param_data["parameters"]["geolocation"]['geolite2-city-include-ipv6'],
        "geo-location-geolite2-country": slb_param_data["parameters"]["geolocation"]['geo-location-geolite2-country']
    }
    system = {
        "geo-location": geolocation
    }
    body = {
        "system": system
    }
    try:
        response = requests.post(url, headers=headers,
                                 data=json.dumps(body), verify=False)
        if response.status_code != 200:
            logger.error("Failed to configure geo location")
            logger.error(response.text)
        else:
            logger.info("Successfully Configured geo location: " + controller_name)
            print("Successfully Configured geo location: " + controller_name)
    except Exception as e:
        logger.error('Error in configuring   geo location: ', exc_info=True)


def write_memory(base_url, authorization_token):
    """
    Function to save configurations on active partition
    :param base_url: Base url of AXAPI
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
    url = "".join([base_url, "/active-partition"])

    response = requests.get(url, headers=headers, verify=False)
    partition = json.loads(response.text)['active-partition']['partition-name']

    if partition is None:
        print("Failed to get partition name")
        logger.error("Failed to get partition name")
    else:
        url = "".join([base_url, "/write/memory"])
        data = {
            "memory": {
                "partition": partition
            }
        }
        try:
            response = requests.post(url, headers=headers,
                                     data=json.dumps(data), verify=False)
            if response.status_code != 200:
                logger.error("Failed to run write memory command")
                logger.error(response.text)
            else:
                logger.info("Configurations are saved on partition: " + partition)
                print("Configurations are saved on partition: " + partition)
        except Exception as e:
            logger.error('Error in writing to memory : ', exc_info=True)


controller_list = ["masterController","memberController"]
site_list = ["site1","site2","site3","site4"]

# get site devices public ips
print("Gathering public and private ip addresses for site devices.")
master_config=slb_param_data["parameters"]["masterConfigDetails"]
member_config=slb_param_data["parameters"]["memberConfigDetails"]

site_public_ips = [[master_config["site1MngmtPublicIp"],master_config["site1Password"]],
                   [master_config["site2MngmtPublicIp"],master_config["site2Password"]],
                   [member_config["site1MngmtPublicIp"],member_config["site1Password"]],
                   [member_config["site2MngmtPublicIp"],member_config["site2Password"]]]
site_sec_pub_ips = [master_config["site1SecPublicIpData1"],master_config["site2SecPublicIpData1"],
                    member_config["site1SecPublicIpData1"],member_config["site2SecPublicIpData1"]]
# get site device private ips and secondary ips
site_data1_sec_pvt_ip = [master_config["site1SecPrivateIpData1"],master_config["site2SecPrivateIpData1"],
                         member_config["site1SecPrivateIpData1"],member_config["site2SecPrivateIpData1"]]

servers = ['vth-server1', 'vth-server2', 'vth-server3', 'vth-server4']
servers_pvt_ips = [master_config["server1PrivateIp"],master_config["server2PrivateIp"],member_config["server1PrivateIp"],
                   member_config["server2PrivateIp"]]
# vms_controller_ips will store the public ip addresses of the management interfaces of controller
vm_controller_ips =[[master_config["controllerMngmtPublicIp"],master_config["controllerPassword"]],
                    [member_config["controllerMngmtPublicIp"],member_config["controllerPassword"]]]
controller_sec_pvt_ip_data1 = [master_config["controllerSecPrivateIpData1"],member_config["controllerSecPrivateIpData1"]]

count = 1

for ith in range(len(site_list)):
    # Base URL of AXAPIs
    base_url = "https://{0}/axapi/v3".format(site_public_ips[ith][0])
    username = "admin"
    print(
        "--------------------------------------------------------------------------------------------------------------------")
    authorization_token = get_auth_token(username, site_public_ips[ith][1], base_url)
    configure_ethernets(base_url, authorization_token)

    configure_server(slb_param_data, base_url, authorization_token, count, site_list[ith], servers_pvt_ips,
                     servers)
    configure_service_group(slb_param_data, base_url, authorization_token, count, site_list[ith], servers)
    configure_virtual_server(slb_param_data, base_url, authorization_token, count, site_list[ith],
                             site_data1_sec_pvt_ip[ith])
    configure_site_device(base_url, authorization_token, site_list[ith])

    # because sites in first region will have different next hop addresses with the sites in second region
    # we use the below if condition to pass next hop values to the function

    if count < 3:
        configure_default_route(base_url, authorization_token, site_list[ith],
                                slb_param_data["parameters"]["rib-list_region1"])
    else:
        configure_default_route(base_url, authorization_token, site_list[ith],
                                slb_param_data["parameters"]["rib-list_region2"])
    count += 1

    write_memory(base_url, authorization_token)

count = 1
# configuration for controller devices
print(
    "--------------------------------------------------------------------------------------------------------------------")
print("Configuring controller devices")
for ith in range(len(vm_controller_ips)):
    base_url = "https://{0}/axapi/v3".format(vm_controller_ips[ith][0])
    username = "admin"
    authorization_token = get_auth_token(username, vm_controller_ips[ith][1], base_url)
    configure_ethernets(base_url, authorization_token)
    configure_gslb_server(slb_param_data, base_url, authorization_token, count, controller_list[ith],
                          controller_sec_pvt_ip_data1[count - 1])

    # configuring master controller
    if ith == 0:
        configure_service_ip(slb_param_data, base_url, authorization_token, controller_list[ith], site_data1_sec_pvt_ip,
                             site_sec_pub_ips)
        configure_site(site_public_ips, base_url, authorization_token, controller_list[ith])
        configure_gslb_policy(slb_param_data, base_url, authorization_token, controller_list[ith])
        configure_gslb_zone(slb_param_data, base_url, authorization_token, controller_list[ith])
        configure_controller_and_status_interval(slb_param_data, base_url, authorization_token,
                                                 controller_list[ith])
        configure_controller_group(slb_param_data, base_url, authorization_token, count, controller_list[ith])
        enable_geo_location(slb_param_data, base_url, authorization_token, controller_list[ith])

    # # configuring member controller
    else:
        configure_controller_group(slb_param_data, base_url, authorization_token, count,
                                   controller_list[ith], vm_controller_ips[0][0])

    # because controller in first region will have different next hop address with the controller in second region
    # we use the below if condition to pass next hop values to the function
    if count < 2:
        configure_default_route(base_url, authorization_token, controller_list[ith],
                                slb_param_data["parameters"]["rib-list_region1"])
    else:
        configure_default_route(base_url, authorization_token, controller_list[ith],
                                slb_param_data["parameters"]["rib-list_region2"])
    write_memory(base_url, authorization_token)

    count += 1
