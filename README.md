# Check-For-DNS-Clients

To use this script, follow the answer suggestion on this page (https://superuser.com/questions/1229515/windows-dns-server-how-to-find-out-who-made-a-query) to enable Debug Logging on your DNS server. Once it is enabled you can run the script and point the logfile argument to the debug log file created by the server. The script will try to do a DNS lookup for each IP as it runs and give you an output of IPs/Hostnames that are using the server for DNS.

You can also have it check the DNS queries against the Cisco Umbrella list of the top 1 million websites (http://s3-us-west-1.amazonaws.com/umbrella-static/index.html) and report back any websites no in that list. Still testing this feature to increase speed, it is too slow to be useful at this point.


Examples:
### checks the dns.log file and returns all DNS clients in a CSV as well as the terminal
get-dnsclients.ps1 -logfile \\\hostname\C$\dns.log 
get-dnsclients.ps1 -logfile C:\dns.log 

### Finds any DNS queries not in the top 1 million domains file that it downloads
get-dnsclients.ps1 -logfile \\\hostname\C$\dns.log -FindUnpopular 

### The following will add the customignores arguments to a CSV to ignore in the future while running the FindUnpopular option
get-dnsclients.ps1 -logfile \\\hostname\C$\dns.log -FindUnpopular -CustomIgnores windows.com,office.com,rackspace.com 
