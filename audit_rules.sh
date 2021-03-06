#!/bin/bash

if ! command -v auditctl; then
    echo "auditctl not found, exiting"
    exit 1
fi

# delete all rules
auditctl -D

# Configure audit properties
auditctl -e 1
auditctl -b 32678

auditctl -w /usr/bin -F auid!=-1 -F perm=wa -k binaries
auditctl -w /usr/sbin -F auid!=-1 -F perm=wa -k binaries
auditctl -w /usr/share/bin -F auid!=-1 -F perm=wa -k binaries
auditctl -w /usr/local/bin -F auid!=-1 -F perm=wa -k binaries
auditctl -w /usr/local/sbin -F auid!=-1 -F perm=wa -k binaries
auditctl -w /bin -F auid!=-1 -F perm=wa -k binaries
auditctl -w /sbin -F auid!=-1 -F perm=wa -k binaries

auditctl -w /usr/lib -F auid!=-1 -F perm=wa -k libraries
auditctl -w /usr/lib64 -F auid!=-1 -F perm=wa -k libraries
auditctl -w /lib -F auid!=-1 -F perm=wa -k libraries
auditctl -w /lib64 -F auid!=-1 -k libraries

# collapsed because of the file_paths_query
auditctl -w /etc -F auid!=-1 -F perm=wa -k etc_files

auditctl -a always,exit -F arch=b64 -F auid!=-1 -S execve,execveat -k syscall_exe
auditctl -a always,exit -F arch=b32 -F auid!=-1 -S execve,execveat -k syscall_exe

# list all rules
auditctl -l
