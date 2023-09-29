### Global Server Load Balancing (GSLB)
A hybrid cloud configuration as a Global Server Load balancer (GSLB) between two regions residing in same or different cloud or on-premise environments. It provides flexibility to implement disaster recovery site.

It requires atleast two Thunder instances in each region or location. One instance serves as the master controller, while the other functions as the site device. It is possible to configure multiple site devices, but it is recommended to have a minimum of three site devices to ensure seamless failover and effective disaster recovery.

Both regions should maintain an equivalent number of resources, whether hosted in the cloud or on-premise.

To create and install three thunder instances in any one region use Thunder-3NIC-3VM template. Same template can be used to install in another region.


**Files**

    1. HYBRID_CLOUD_CONFIG_GSLB_PARAM.json Parameter file for hybrid cloud configuration with defalut values.
    2. HYBRID_CLOUD_CONFIG_GSLB.py Python script for configuring hybrid cloud configuration in both region.

**Requirement**

    1. Install python3 version

**Execution Step**

For deploying A10 ADC in the Azure environment With the one click you will be able to deploy new 3nic-3vm template in Azure with vThunder .

# Deploy New Stack with BYOL vThunder

Deploy new resource with BYOL vThunder license by clicking on the "launch stack" button below. You need to accept the terms and subscribe on the marketplace before deploying the stack if you are deploying the stack for the first time. To accept the terms for BYOL please <a href="https://portal.azure.com/#view/Microsoft_Azure_Marketplace/GalleryItemDetailsBladeNopdl/id/a10networks.a10-vthunder-adc-521/selectionMode~/false/resourceGroupId//resourceGroupLocation//dontDiscardJourney~/false/selectedMenuId/home/launchingContext~/%7B%22galleryItemId%22%3A%22a10networks.a10-vthunder-adc-521vthunder-adc-521-byol%22%2C%22source%22%3A%5B%22GalleryFeaturedMenuItemPart%22%2C%22VirtualizedTileDetails%22%5D%2C%22menuItemId%22%3A%22home%22%2C%22subMenuItemId%22%3A%22Search%20results%22%2C%22telemetryId%22%3A%222be5e5ea-39b2-4800-a666-a8ac16ce5bf1%22%7D/searchTelemetryId/b869d4ae-a128-4813-b0c4-2d3576636597/isLiteSearchFlowEnabled~/false">click here</a>.

<a href="https://portal.azure.com/#create/Microsoft.Template">  
   <img src="https://gitlab.a10networks.com/dev-shared-infra/a10-aws-cft-internal/-/raw/feature/AWS-CFT-TEMPLATES-v1.2.0/CFT-TEMPLATES/A10-vThunder_ADC-3NIC-3VM/LAUNCHSTACK.png"/></a>
