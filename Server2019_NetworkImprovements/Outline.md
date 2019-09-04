Server 2019 Network updates
 * Low Extra Delay Background Transpot (LEDBAT)
   * Network congestion control provider designed to automatically yield bandwidth available when the network is not in use.
   * intended for use in deploying large, critical updates across an IT environment without impacting customer facing services and associated bandwidth.
   https://techcommunity.microsoft.com/t5/Networking-Blog/Top-10Networking-Feature-in-Windows-Server-2019-9-LEDBAT-8211/ba-p/339745
   https://www.youtube.com/watch?v=6fBGs7t3kRM
   https://techcommunity.microsoft.com/t5/Networking-Blog/Support-forLEDBAT-Public-Service-Announcement/ba-p/339796
 * Encrypted Networks
   * Subnets need to be marked as 'Encryption Enabled.'
   * Utilizes Datagram Transport Layer Security (DTLS) on the virtual subnet
   * Virtual network encryption requires:
     * Encription certificates installed on each of the DSN-enabled Hyper-V hosts
     * A credential object in the Network Controller referenceing the thumbpring of that certificates
     * Configuration on each of the Virtual Networks contain subnets taht require encryption.
   * Once encryption is configured, the network is encrypted in addition to any application level encryption
   https://docs.microsoft.com/en-us/windows-server/networking/sdn/vnet-encryption/sdn-config-vnet-encryption
 * Network performance improvements for virtual workloads
   * Maximizes the network throughput to virtual machines without requiring you to constantly tune or over provision your host.
   * Receive Segment Coalescing the vSwitch (Windows Server 2019 & Windows 10, version 1809)
     * Coalesces multiple TCP segments into a larger segment before data traversing the vSwitch.
   * Dynamic Virtual Machine Multi-Queue (VMMQ)
 * High performance SDN gateways
   * improves the performance for IPsec and GRE connections, providing ultra-high-performance throughput with much less CPU utilization
   * https:docs.microsoft.com/en-us/windows-server/networking/sdn/gateway-performance