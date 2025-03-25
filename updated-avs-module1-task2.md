# Module 1 Task 2: Configure NSX-T to Establish Connectivity within AVS

## NSX-T on Azure VMware Solution (AVS)

After deploying Azure VMware Solution, you can configure NSX-T network segments either through the NSX-T Manager or directly from the Azure portal. Once configured, these segments are visible across Azure VMware Solution, NSX-T Manager, and vCenter.

NSX-T comes pre-provisioned with:
- A default NSX-T Tier-0 (T0) gateway in Active/Active mode
- A default NSX-T Tier-1 (T1) gateway in Active/Standby mode

These gateways enable you to connect network segments (logical switches) and provide both East-West and North-South connectivity. Note that virtual machines will not have IP addresses until statically or dynamically assigned via DHCP server or DHCP relay.

## In this section, you will learn how to:

- Create additional NSX-T Tier-1 gateways
- Add network segments using NSX-T Manager
- Configure DHCP and DNS services
- Deploy test VMs in the configured segments
- Validate connectivity

## Accessing NSX-T Manager

1. From your jumpbox, open a browser and navigate to the NSX-T URL found in the AVS Private Cloud blade in the Azure Portal
2. Log in using the credentials provided in the Identity tab

## Exercise 1: Verify DNS Forwarder Configuration

> **NOTE:** DNS forwarding services are configured by default in new AVS deployments

AVS DNS forwarding services operate in DNS zones and allow workload VMs to resolve FQDNs to IP addresses. Your SDDC includes default DNS zones for both Management Gateway and Compute Gateway, each with preconfigured DNS services.

**To verify DNS configuration:**

1. Ensure the **POLICY** view is selected in the top navigation bar
2. Navigate to **Networking** in the left menu
3. Select **DNS**
4. Click **DNS Services**
5. Click the ellipsis (⋮) button next to the default service and select **Edit** to view the settings
6. Review the configuration (do not modify anything) and click **CANCEL**

You can create additional DNS zones or configure more properties of DNS services via the **DNS Zones** tab if needed.

## Exercise 2: Add DHCP Profile in AVS Private Cloud

> **IMPORTANT:** Replace "X" with your group's assigned number and "Y" with your participant number. For participant 10, replace "XY" with "20".

**Required Configuration Values:**

| Configuration | Value |
|---------------|-------|
| DHCP Server IP | 10.XY.50.1/30 |
| Segment Name | WEB-NET-GROUP-XY |
| Segment Gateway | 10.XY.51.1/24 |
| DHCP Range | 10.XY.51.4-10.XY.51.254 |

A DHCP profile specifies the DHCP server type and configuration settings. You can use the default profile or create additional profiles as needed for your networking requirements.

### Step 1: Add DHCP Profile

1. In the NSX-T Manager console, navigate to **Networking**
2. Click **DHCP**
3. Click **ADD DHCP PROFILE**

### Step 2: Configure DHCP Profile

1. Enter **DHCP-Profile-GROUP-XY-AVS** as the profile name (replace XY with your group/participant numbers)
2. Ensure **DHCP Server** is selected as the type
3. In the IPv4 Server IP Address field, enter **10.XY.50.1/30**
4. Leave the Lease Time at default value or adjust as needed
5. Click **SAVE**

## Exercise 3: Create an NSX-T Tier-1 Logical Router

NSX-T uses Logical Routers (LR) that can perform both distributed and centralized functions. In AVS, NSX-T is deployed with a default T0 Logical Router and a default T1 Logical Router.

> **NOTE:** The T0 LR in AVS cannot be modified by AVS customers, but T1 LRs can be fully configured and additional T1 LRs can be added as needed.

### Step 1: Add Tier-1 Gateway

1. Navigate to **Networking**
2. Click **Tier-1 Gateways**
3. Click **ADD TIER-1 GATEWAY**

### Step 2: Configure Tier-1 Gateway

1. Enter **GROUP-XY-T1** as the name (replace XY with your group/participant numbers)
2. Select the default T0 Gateway (typically named TNT**-T0)
3. Click **SAVE**
4. When prompted "Want to continue configuring this Tier-1 Gateway?", click **NO**

## Exercise 4: Add the DHCP Profile to the T1 Gateway

### Step 1: Configure DHCP on Tier-1 Gateway

1. Locate your newly created T1 Gateway in the list
2. Click the ellipsis (⋮) next to it and select **Edit**
3. Click **Set DHCP Configuration**
4. Ensure **DHCP Server** is selected for Type
5. Select the DHCP Server Profile you created earlier
6. Click **SAVE**
7. Expand the **Route Advertisement** section and ensure that ALL options are enabled:
   - Connected Segments and Service Ports
   - Stateless IP Configuration
   - DNS Forwarder IP
   - LB VIP
   - NAT IP
   - IPSec Local Endpoint
8. Click **SAVE** again to confirm all changes
9. Click **CLOSE EDITING**

## Exercise 5: Create Network Segment for AVS VM Workloads

Network segments are logical networks for workload VMs in the SDDC compute network. Azure VMware Solution supports three types:

- **Routed segments** (default): Connected to other logical networks in the SDDC and, through the SDDC firewall, to external networks
- **Extended segments**: Extend an existing L2VPN tunnel, providing a single IP address space spanning the SDDC and on-premises network
- **Disconnected segments**: Have no uplink and provide isolated networks; typically created by HCX or can be manually created

### Step 1: Add Network Segment

1. Navigate to **Networking**
2. Click **Segments**
3. Click **ADD SEGMENT**

### Step 2: Configure Network Segment

1. Enter **WEB-NET-GROUP-XY** as the Segment Name (replace XY with your group/participant numbers)
2. Select your newly created Tier-1 Gateway (**GROUP-XY-T1**) as the Connected Gateway
3. Select the pre-configured overlay Transport Zone (typically named **TNTxx-OVERLAY-TZ**)
4. In the Subnets field, enter the Gateway IP address with CIDR notation: **10.XY.51.1/24**
5. Click **SET DHCP CONFIG**

### Step 3: Configure DHCP on Network Segment

1. Ensure **Gateway DHCP Server** is selected for DHCP Type
2. Set the DHCP Config toggle to **Enabled**
3. In the DHCP Ranges field, enter: **10.XY.51.4-10.XY.51.254**
4. For DNS Servers, enter: **1.1.1.1**
5. Click **Apply**
6. Click **SAVE**
7. When prompted for additional configuration, click **NO**

> **IMPORTANT:** The IP address range must use a non-overlapping RFC1918 address block to ensure proper connectivity to VMs on the new segment.

## Next Steps

After completing this configuration, you can:
- Deploy test VMs on your segment
- Validate connectivity between VMs
- Configure additional network services as needed

## References

- [Create or Modify a Network Segment](https://docs.vmware.com/en/VMware-Cloud-on-AWS/services/com.vmware.vmc-aws-networking-security/GUID-267DEADB-BD01-46B7-82D5-B9AA210CA9EE.html)
- [Configure Segment DHCP Properties](https://docs.vmware.com/en/VMware-Cloud-on-AWS/services/com.vmware.vmc-aws-networking-security/GUID-92772AF8-632B-4C6A-9D52-C0B91EB396DB.html)
- [Azure VMware Solution Documentation](https://docs.microsoft.com/en-us/azure/azure-vmware/)
