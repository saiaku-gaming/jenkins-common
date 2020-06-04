import os
import zipfile
import subprocess
import requests
import sys
from requests.auth import HTTPBasicAuth
from pathlib import Path

crashId = sys.argv[1]
user = 'jenkins'
print(f"Starting diagnostics")
response = requests.get(f'https://qa.valhalla-game.com/api/crash/{crashId}',
                        allow_redirects=True,
                        auth=HTTPBasicAuth(user, os.environ['JENKINS_API_TOKEN']))
metadata = response.json()
binaryStorageSecret = os.environ['BINARY_STORAGE_SECRET']
head, crashFolderZip = os.path.split(metadata.get("pathOnDisc"))
gameBinariesFolder = f'WindowsNoEditor{metadata.get("crashInVersion")}'
gameBinariesZip = f'{gameBinariesFolder}.zip'
print(f"got metadata {metadata}")
print(f"Downloading crash")
with requests.get(
        f'https://qa.valhalla-game.com/api/crash/{crashId}/download',
        allow_redirects=True,
        stream=True,
        auth=HTTPBasicAuth(user, os.environ['JENKINS_API_TOKEN'])) as r:
    with open(crashFolderZip, 'wb') as f:
        for chunk in r:
            f.write(chunk)
print(f"Downloading game binaries")
gameUrl = f'http://gungnir.teamsamst.com:8899/storage?path=valhalla-windows-client&name={gameBinariesZip}'
with requests.get(gameUrl, allow_redirects=True, stream=True, headers={'Authorization': binaryStorageSecret}) as r:
    with open(gameBinariesZip, 'wb') as f:
        for chunk in r:
            f.write(chunk)
print(f"Extracting game binaries")
with zipfile.ZipFile(gameBinariesZip, 'r') as zip_ref:
    zip_ref.extractall(gameBinariesFolder)
print(f"Extracting crash")
crashFolder = f"{os.path.abspath(gameBinariesFolder)}\\valhalla\\Saved\\Crashes\\{Path(crashFolderZip).stem}"
with zipfile.ZipFile(crashFolderZip, 'r') as zip_ref:
    zip_ref.extractall(crashFolder)
print(f"Getting diagostics tool")
with requests.get("https://github.com/saiaku-gaming/jenkins-common/raw/master/MinidumpDiagnostics.exe",
                  stream=True) as r:
    with open("MinidumpDiagnostics.exe", 'wb') as f:
        for chunk in r:
            f.write(chunk)

symbolFolder = f"{os.path.abspath(gameBinariesFolder)}\\valhalla\\Binaries\\Win64"
print(f"Symbol folder {symbolFolder}")

args = ("MinidumpDiagnostics.exe", f"{crashFolder}\\UE4Minidump.dmp")
popen = subprocess.Popen(args, stdout=sys.stdout, stderr=sys.stderr, env={
                         "_NT_SYMBOL_PATH": symbolFolder})
code = popen.wait()
print(f"diag code {code}")

files = {'file': open(f"{crashFolder}\\Diagnostics.txt")}
crashId = metadata.get('id')
response = requests.post(f'https://qa.valhalla-game.com/api/crash/{crashId}/diagnostics',
                         files=files,
                         data=data,
                         allow_redirects=True,
                         auth=HTTPBasicAuth(user, os.environ['JENKINS_API_TOKEN']))
print(f"uploaded diag with response {response}")
