# to transfer data into the sandbox environment from your laptop
# open terminal app
# add to file ssh config for HSPD12 authentication:
"PKCS11Provider=/usr/lib/ssh-keychain.dylib" >> ~/.ssh/config

# sftp to the ingress node in ABLE
b54328@mcsvpn013 ~ % sftp ingress-abledtn.cels.anl.gov
The authenticity of host 'ingress-abledtn.cels.anl.gov (146.139.250.4)' can't be established.
ECDSA key fingerprint is SHA256:bPm5RepQkmQz/Pukl6iNRD+WBddsF1iHDV+n+nu7ZBY.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'ingress-abledtn.cels.anl.gov' (ECDSA) to the list of known hosts.
Enter PIN for 'Key For PIV Authentication (AlexApple, Inc.': 
Connected to ingress-abledtn.cels.anl.gov.
sftp> 

# now you are connected after entering your secure HSPD12 code

# start transferring files you wish to put into the transfer node
# (ingress-only) Use lpwd to see what folder you are locally in and lcd testfolder to change to a different local folder that contains the files you want to upload
sftp> lpwd
Local working directory: /Users/b54328
sftp> lcd /Users/b54328/Documents/Work/SecureComputing/AgenticFramework-Tarak
sftp> lls  
GSE255800_extracted
sftp>   

# (ingress-only) If you are trying to upload files then do a put filename or put * to upload all files in current folder (once uploaded files will show up in /ableinbox/username/ on any of the ABLE nodes)
sftp> put *
Uploading GSM8080315_sample1_R0_barcodes.tsv.gz to /b54328/GSM8080315_sample1_R0_barcodes.tsv.gz
GSM8080315_sample1_R0_barcodes.tsv.gz                                           100%   45KB 348.8KB/s   00:00    
Uploading GSM8080315_sample1_R0_features.tsv.gz to /b54328/GSM8080315_sample1_R0_features.tsv.gz
GSM8080315_sample1_R0_features.tsv.gz                                           100%  276KB   1.2MB/s   00:00    
Uploading GSM8080315_sample1_R0_matrix.mtx.gz to /b54328/GSM8080315_sample1_R0_matrix.mtx.gz
GSM8080315_sample1_R0_matrix.mtx.gz                                             100%  157MB   2.4MB/s   01:06    
Uploading GSM8080316_sample2_R10_barcodes.tsv to /b54328/GSM8080316_sample2_R10_barcodes.tsv
GSM8080316_sample2_R10_barcodes.tsv                                             100%  399KB   1.6MB/s   00:00    
Uploading GSM8080316_sample2_R10_features.tsv to /b54328/GSM8080316_sample2_R10_features.tsv
GSM8080316_sample2_R10_features.tsv                                             100% 1445KB   2.1MB/s   00:00    
Uploading GSM8080316_sample2_R10_matrix.mtx to /b54328/GSM8080316_sample2_R10_matrix.mtx
GSM8080316_sample2_R10_matrix.mtx                                                53%  483MB   2.3MB/s   03:00 ETA
GSM8080316_sample2_R10_matrix.mtx                                               100%  907MB   2.4MB/s   06:21    
Uploading GSM8080317_sample3_R100_barcodes.tsv.gz to /b54328/GSM8080317_sample3_R100_barcodes.tsv.gz
GSM8080317_sample3_R100_barcodes.tsv.gz                                         100%   79KB 840.9KB/s   00:00    
Uploading GSM8080317_sample3_R100_features.tsv.gz to /b54328/GSM8080317_sample3_R100_features.tsv.gz
GSM8080317_sample3_R100_features.tsv.gz                                         100%  276KB   1.2MB/s   00:00    
Uploading GSM8080317_sample3_R100_matrix.mtx.gz to /b54328/GSM8080317_sample3_R100_matrix.mtx.gz
GSM8080317_sample3_R100_matrix.mtx.gz                                           100%  191MB   2.3MB/s   01:22    
Uploading GSM8080318_sample4_R1000_barcodes.tsv to /b54328/GSM8080318_sample4_R1000_barcodes.tsv
GSM8080318_sample4_R1000_barcodes.tsv                                           100%  288KB   1.9MB/s   00:00    
Uploading GSM8080318_sample4_R1000_features.tsv to /b54328/GSM8080318_sample4_R1000_features.tsv
GSM8080318_sample4_R1000_features.tsv                                           100% 1445KB   3.1MB/s   00:00    
Uploading GSM8080318_sample4_R1000_matrix.mtx to /b54328/GSM8080318_sample4_R1000_matrix.mtx
GSM8080318_sample4_R1000_matrix.mtx                                             100%  773MB   2.4MB/s   05:28  

# Now log on to the ABLE no-internet server and you will see the data in /ableinbox/username
# Move the data where your program will access it from
Last login: Fri Dec 12 10:47:52 2025 from 146.139.246.197
[b54328@svr-rkl-ablelogin ~]$ ls /ableinbox/b54328
GSM8080315_sample1_R0_barcodes.tsv.gz    GSM8080317_sample3_R100_barcodes.tsv.gz
GSM8080315_sample1_R0_features.tsv.gz    GSM8080317_sample3_R100_features.tsv.gz
GSM8080315_sample1_R0_matrix.mtx.gz      GSM8080317_sample3_R100_matrix.mtx.gz
GSM8080316_sample2_R10_barcodes.tsv      GSM8080318_sample4_R1000_barcodes.tsv
GSM8080316_sample2_R10_features.tsv      GSM8080318_sample4_R1000_features.tsv
GSM8080316_sample2_R10_matrix.mtx        GSM8080318_sample4_R1000_matrix.mtx
[b54328@svr-rkl-ablelogin ~]$ ls -tlr
total 2
-rw-r--r--. 1 b54328 users 1612 Nov 11 16:19 API_Call_Basic_v0.0.py
drwxr-x---. 4 b54328 users 4096 Nov 14 14:02 ollama
-rw-r--r--. 1 b54328 users 1977 Nov 14 15:27 API_Call_ollama_v0.0.py
drwxr-x---. 3 b54328 users 4096 Dec  2 22:17 agentic_framework
[b54328@svr-rkl-ablelogin ~]$ cd agentic_framework/
[b54328@svr-rkl-ablelogin agentic_framework]$ mkdir GSE255800_extracted
[b54328@svr-rkl-ablelogin agentic_framework]$ mv /ableinbox/b54328/GSM* GSE255800_extracted/.
