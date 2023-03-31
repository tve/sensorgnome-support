Sensorgnome Software Upgrade
=======================

Simple scripts called by sg-control to upgrade the software using apt.

## Adding or changing a repository and its key

See [DigitalOcean tutorial](https://www.digitalocean.com/community/tutorials/how-to-handle-apt-key-and-add-apt-repository-deprecation-using-gpg-to-add-external-repositories-on-ubuntu-22-04)

```
# Download the key from the keyserver
sudo gpg --homedir /tmp --no-default-keyring --keyring ./sources/R.gpg \
  --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9

# Create the repo .list file
echo "deb [signed-by=/usr/share/keyrings/R.gpg] https://cloud.r-project.org/bin/linux/ubuntu jammy-cran40/" > sources/R.list
```
