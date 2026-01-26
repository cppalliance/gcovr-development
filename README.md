
## gcovr development

When gcovr is run with the --html-template-dir flag, customized templates may be used to modify the appearance of html.  

### Instructions

First-time setup.

Requires Ubuntu linux or WSL.

```
sudo apt-get update
sudo apt-get install -y python3-venv build-essential
sudo python3 -m venv ~/venv
```

edit ~/.bashrc and add this at the end:

```
. ~/venv/bin/activate
pip3 install gcovr
```

And also manually run the above commands.

Set up the repo. Use this exact path /opt/github/cppalliance. 

In the following section, change "ubuntu" to whatever your own username is.

```
repodir=/opt/github/cppalliance
sudo mkdir -p $repodir
sudo chown -R ubuntu:ubuntu $repodir 
cd $repodir
git clone https://github.com/cppalliance/gcovr-development
cd gcovr-development
```

The modifiable templates are in the `templates/` directory.  

Run this each time:  

```
./build.sh
```

Files will be output to `/opt/github/cppalliance/json/gcovr/`, or the location can be modified in `build.sh`. Run `build.sh` each time after modifying the templates.  

### WSL Notes

Use Ubuntu 24.04: `wsl --install Ubuntu-24.04`

Modify build.sh to send files to `/mnt/c/output/` where they can be easily viewed from the system's main browser.

### Administrator Notes

Remove .gitignore so all files will be commited into git.

```
rm boost-root/.gitignore 
rm -rf boost-root/.git
rm json/.gitignore
rm -rf json/.git
```

This project is pushing the limits of github due to large files. An alternative distribution method would be to zip the contents into a tar.gz file and upload them to dl.cpp.al. It may need to be converted to that.

When adding and pushing contents to github try:  

```
git config --global http.postBuffer 157286400
```

The entire contents of this repo can be recreated by going into the json directory `cd json` and running the script https://github.com/cppalliance/ci-automation/blob/master/scripts/lcov-jenkins-gcc-13.sh 


