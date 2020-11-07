#!/bin/bash

###### 절대경로(realpath) ######
WORK_PATH="$(dirname $(realpath -s $0))"
echo $WORK_PATH
UPSTREAM_ISO="$WORK_PATH/custom-img/extract-cd"

cat <<EOF > apt-ftparchive.conf
Dir {
	ArchiveDir "custom-img/extract-cd/";
	CacheDir "/tmp/cache";
};
Default {
	Packages::Compress ". gzip bzip2";
	Sources::Compress ". gzip bzip2";
	Contents::Compress ". gzip bzip2";
};
TreeDefault {
	BinCacheDB "packages-\$(SECTION)-\$(ARCH).db";
	Directory "pool/\$(SECTION)";
	Packages "\$(DIST)/\$(SECTION)/binary-\$(ARCH)/Packages";
	SrcDirectory "pool/\$(SECTION)";
	Sources "\$(DIST)/\$(SECTION)/source/Sources";
	Contents "\$(DIST)/Contents-\$(ARCH)";
};
Tree "dists/focal" {
	Sections "main contrib";
	Architectures "amd64";
}
EOF

cat <<EOF > release.conf
APT::FTPArchive::Release::Origin "Ubuntu";
APT::FTPArchive::Release::Label "Ubuntu";
APT::FTPArchive::Release::Suite "focal";
APT::FTPArchive::Release::Version "20.04";
APT::FTPArchive::Release::Codename "focal";
APT::FTPArchive::Release::Architectures "amd64";
APT::FTPArchive::Release::Components "main contrib";
APT::FTPArchive::Release::Description "Ubuntu 20.04 LTS";
EOF

mkdir /tmp/cache
apt-ftparchive generate apt-ftparchive.conf
apt-ftparchive -c release.conf release $UPSTREAM_ISO/dists/focal > $UPSTREAM_ISO/dists/focal/Release

# chroot 환경에서 apt install ubuntu-keyring/jin --reinstall 필요
RUID=$(who | awk 'FNR == 1 {print $1}')
sudo chown ${RUID}:${RUID} $UPSTREAM_ISO/dists -R
sudo chmod a+w $UPSTREAM_ISO/* -R
sudo su - ${RUID} -c "gpg --default-key 9FA298A1E42665B8 --output $UPSTREAM_ISO/dists/focal/Release.gpg -ba $UPSTREAM_ISO/dists/focal/Release"
sudo su - ${RUID} -c "gpg --default-key 9FA298A1E42665B8 --clearsign -o $UPSTREAM_ISO/dists/focal/InRelease $UPSTREAM_ISO/dists/focal/Release"

rm -f apt-ftparchive.conf release.conf
rm -rf /tmp/cache
