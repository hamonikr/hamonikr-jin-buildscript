#!/bin/bash

# ISO 이미지 안의 패키지 저장소 업데이트
cat <<EOF > apt-ftparchive.conf
Dir {
	ArchiveDir "./custom-img/extract-cd/";
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

# sudo chown $USER:$USER build/upstream-iso build/cache -R
# mkdir -p ./build/upstream-iso/dists/{focal,groovy}/main/{binary-amd64,source}
# mkdir -p ./build/upstream-iso/pool/main
# mkdir -p ./build/cache
mkdir /tmp/cache
apt-ftparchive generate apt-ftparchive.conf
apt-ftparchive -c release.conf release /media/hamonikr/e1ed61eb-707b-467a-ba26-1cc66d7af35c/hamonikr/work/hamonikr4.0-jin-beta-buildscript/custom-img/extract-cd/dists/focal > /media/hamonikr/e1ed61eb-707b-467a-ba26-1cc66d7af35c/hamonikr/work/hamonikr4.0-jin-beta-buildscript/custom-img/extract-cd/dists/focal/Release

# sudo 로 실행하면 서명이 정상적으로 안되므로 빌드하는 일반 유저로 실행해야 함.
# 빌드키를 사용하기 위해서는 sudo apt install ubuntu-keyring/jin --reinstall 실행 후
# 하모니카 빌드에 사용하는 비밀키를 import 하고 실행해야 함.
RUID=$(who | awk 'FNR == 1 {print $1}')
sudo chown ${RUID}:${RUID} /media/hamonikr/e1ed61eb-707b-467a-ba26-1cc66d7af35c/hamonikr/work/hamonikr4.0-jin-beta-buildscript/custom-img/extract-cd/dists -R
sudo chmod a+w /media/hamonikr/e1ed61eb-707b-467a-ba26-1cc66d7af35c/hamonikr/work/hamonikr4.0-jin-beta-buildscript/custom-img/extract-cd/* -R
sudo su - ${RUID} -c 'gpg --default-key 9FA298A1E42665B8 --output /media/hamonikr/e1ed61eb-707b-467a-ba26-1cc66d7af35c/hamonikr/work/hamonikr4.0-jin-beta-buildscript/custom-img/extract-cd/dists/focal/Release.gpg -ba /media/hamonikr/e1ed61eb-707b-467a-ba26-1cc66d7af35c/hamonikr/work/hamonikr4.0-jin-beta-buildscript/custom-img/extract-cd/dists/focal/Release'

rm -f apt-ftparchive.conf release.conf