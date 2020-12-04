# Check-For-DNS-Clients

To use this script, follow the answer suggestion on this page (https://superuser.com/questions/1229515/windows-dns-server-how-to-find-out-who-made-a-query) to enable Debug Logging on your DNS server. Once it is enabled you can run the script and point the logfile argument to the debug log file created by the server.

Examples:
get-dnsclients.ps1 -logfile \\hostname\C$\dns.log
get-dnsclients.ps1 -logfile C:\dns.log
