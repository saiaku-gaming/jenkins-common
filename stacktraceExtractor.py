import os
import zipfile
import subprocess
import requests
from requests.auth import HTTPBasicAuth
from pathlib import Path

crashId = sys.argv[1]
user = 'jenkins'
response = requests.get(f'https://qa.valhalla-game.com/crash/{crashId}',
                        allow_redirects=True,
                        auth=HTTPBasicAuth(user, os.environ['JENKINS_API_TOKEN']))
metadata = response.json()
binaryStorageSecret = os.environ['BINARY_STORAGE_SECRET']
head, crashFolderZip = os.path.split(metadata.get("pathOnDisc"))
gameBinariesFolder = f'WindowsNoEditor{metadata.get("crashInVersion")}'
gameBinariesZip = f'{gameBinariesFolder}.zip'

with requests.get(
        f'https://qa.valhalla-game.com/api/crash/{crashId}/download',
        allow_redirects=True,
        stream=True,
        auth=HTTPBasicAuth(user, os.environ['JENKINS_API_TOKEN'])) as r:
    with open(crashFolderZip, 'wb') as f:
        for chunk in r:
            f.write(chunk)

gameUrl = f'http://gungnir.teamsamst.com:8899/storage?path=valhalla-windows-client&name={gameBinariesZip}'
with requests.get(gameUrl, allow_redirects=True, stream=True, headers={'Authorization': binaryStorageSecret}) as r:
    with open(gameBinariesZip, 'wb') as f:
        for chunk in r:
            f.write(chunk)

with zipfile.ZipFile(gameBinariesZip, 'r') as zip_ref:
    zip_ref.extractall(gameBinariesFolder)

crashFolder = f"{os.path.abspath(gameBinariesFolder)}\\valhalla\\Saved\\Crashes\\{Path(crashFolderZip).stem}"
with zipfile.ZipFile(crashFolderZip, 'r') as zip_ref:
    zip_ref.extractall(crashFolder)

with requests.get("https://github.com/saiaku-gaming/jenkins-common/raw/master/MinidumpDiagnostics.exe",
                  stream=True) as r:
    with open("MinidumpDiagnostics.exe", 'wb') as f:
        for chunk in r:
            f.write(chunk)

symbolFolder = f"{os.path.abspath(gameBinariesFolder)}\\valhalla\\Binaries\\Win64"

args = ("MinidumpDiagnostics.exe", f"{crashFolder}\\UE4Minidump.dmp")
popen = subprocess.Popen(args, stdout=subprocess.PIPE, env={"_NT_SYMBOL_PATH": symbolFolder})
code = popen.wait()

if(code == 0):
	files = {'file': open(f"{crashFolder}\\Diagnostics.txt")}
	response = requests.post(f'https://qa.valhalla-game.com/api/crash/{metadata.get('id')}/diagnostics',
						files=files,
						data=data,
                        allow_redirects=True,
                        auth=HTTPBasicAuth(user, os.environ['JENKINS_API_TOKEN']))
