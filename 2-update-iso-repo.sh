#!/bin/bash

###### 절대경로(realpath) ######
WORK_PATH="$(dirname $(realpath -s $0))"
echo $WORK_PATH
UPSTREAM_ISO="$WORK_PATH/custom-img/extract-cd"

cat <<EOF > apt-ftparchive.conf
Dir {
	ArchiveDir "$UPSTREAM_ISO/";
};
Default {
	Packages::Compress ". gzip";
	Sources::Compress ". gzip";
	Contents::Compress ". gzip";
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

cat <<EOF > apt-ftparchive-deb.conf
Dir {
	ArchiveDir "$UPSTREAM_ISO/";
};

TreeDefault {
  Directory "pool/";
};

BinDirectory "pool/main" {
  Packages "dists/focal/main/binary-amd64/Packages";
  BinOverride "/opt/indices/override.focal.main";
};

BinDirectory "pool/restricted" {
 Packages "dists/focal/restricted/binary-amd64/Packages";
 BinOverride "/opt/indices/override.focal.restricted";
};

Default {
  Packages {
    Extensions ".deb";
    Compress ". gzip";
  };
};

Contents {
  Compress "gzip";
};
EOF

cat <<EOF > apt-ftparchive-udeb.conf
Dir {
	ArchiveDir "$UPSTREAM_ISO/";
};

TreeDefault {
  Directory "pool/";
};

BinDirectory "pool/main" {
  Packages "dists/focal/main/binary-amd64/Packages";
  BinOverride "/opt/indices/override.focal.main";
};

BinDirectory "pool/restricted" {
  Packages "dists/focal/restricted/binary-amd64/Packages";
  BinOverride "/opt/indices/override.focal.restricted";
};

Default {
  Packages {
    Extensions ".udeb";
    Compress ". gzip";
  };
};

Contents {
  Compress "gzip";
};
EOF

cat <<EOF > release.conf
APT::FTPArchive::Release::Origin "Ubuntu";
APT::FTPArchive::Release::Label "HamoniKR 4.0 Jin";
APT::FTPArchive::Release::Suite "focal";
APT::FTPArchive::Release::Version "20.04";
APT::FTPArchive::Release::Codename "focal";
APT::FTPArchive::Release::Architectures "i386 amd64 source";
APT::FTPArchive::Release::Components "main restricted contrib";
APT::FTPArchive::Release::Description "HamoniKR 4.0 Jin LTS";
EOF

# mkdir /tmp/cache

# 문서에 나온 방식으로 테스트를 위해
# https://help.ubuntu.com/community/InstallCDCustomization
# mkdir -p /opt/indices /opt/apt-ftparchive
# cd /opt/indices/
# DIST=focal
# for SUFFIX in extra.main main main.debian-installer restricted restricted.debian-installer; do
#   wget http://archive.ubuntu.com/ubuntu/indices/override.$DIST.$SUFFIX
# done

cd $WORK_PATH

# apt-ftparchive -c release.conf generate apt-ftparchive-deb.conf
# apt-ftparchive -c release.conf generate apt-ftparchive-udeb.conf
apt-ftparchive -c release.conf generate apt-ftparchive.conf
apt-ftparchive -c release.conf release $UPSTREAM_ISO/dists/focal > $UPSTREAM_ISO/dists/focal/Release

# chroot 환경에서 apt install ubuntu-keyring/jin --reinstall 필요
RUID=$(who | awk 'FNR == 1 {print $1}')
sudo chown ${RUID}:${RUID} $UPSTREAM_ISO/dists -R
sudo chmod a+w $UPSTREAM_ISO/* -R
sudo su - ${RUID} -c "gpg --default-key 9FA298A1E42665B8 --output $UPSTREAM_ISO/dists/focal/Release.gpg -ba $UPSTREAM_ISO/dists/focal/Release"
sudo su - ${RUID} -c "gpg --default-key 9FA298A1E42665B8 --clearsign -o $UPSTREAM_ISO/dists/focal/InRelease $UPSTREAM_ISO/dists/focal/Release"

rm -f apt-ftparchive.conf release.conf
# rm -rf /tmp/cache
