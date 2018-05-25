#!/bin/bash

# This script was adapted from work by Keith James (keithj). The original source
# can be found as part of the wtsi-npg/data_handling project here:
#
#   https://github.com/wtsi-npg/data_handling
#
# iRODS setup added by Iain Bancarz (ib5), adapted from baton:
#   https://github.com/wtsi-npg/baton

set -e -u -x

# The default build branch for all repositories. This defaults to
# TRAVIS_BRANCH unless set in the Travis build environment.
WTSI_NPG_BUILD_BRANCH=${WTSI_NPG_BUILD_BRANCH:=$TRAVIS_BRANCH}
IRODS_RIP_DIR=${IRODS_RIP_DIR:+$IRODS_RIP_DIR}

sudo apt-get install libgd2-xpm-dev # For npg_tracking

# CPAN as in npg_npg_deploy
cpanm --notest --reinstall App::cpanminus
cpanm --quiet --notest --reinstall ExtUtils::ParseXS
cpanm --quiet --notest --reinstall MooseX::Role::Parameterized
cpanm --quiet --notest Alien::Tidyp
cpanm --quiet --notest LWP::Protocol::https
cpanm --quiet --notest https://github.com/chapmanb/vcftools-cpan/archive/v0.953.tar.gz

# Conda
export PATH="$HOME/miniconda/bin:$PATH"
conda create -q --name "$CONDA_TEST_ENV" python=$TRAVIS_PYTHON_VERSION
conda install --name "$CONDA_TEST_ENV" npg_qc_utils

# iRODS
wget -q https://github.com/wtsi-npg/disposable-irods/releases/download/${DISPOSABLE_IRODS_VERSION}/disposable-irods-${DISPOSABLE_IRODS_VERSION}.tar.gz -O /tmp/disposable-irods-${DISPOSABLE_IRODS_VERSION}.tar.gz
tar xfz /tmp/disposable-irods-${DISPOSABLE_IRODS_VERSION}.tar.gz -C /tmp
cd /tmp/disposable-irods-${DISPOSABLE_IRODS_VERSION}
./scripts/download_and_verify_irods.sh
./scripts/install_irods.sh
./scripts/configure_irods.sh

# baton
conda install --name "$CONDA_TEST_ENV" baton

# WTSI NPG Perl repo dependencies
repos=""
for repo in perl-dnap-utilities ml_warehouse npg_tracking npg_seq_common perl-irods-wrap; do
    cd /tmp
    # Always clone master when using depth 1 to get current tag
    git clone --branch master --depth 1 ${WTSI_NPG_GITHUB_URL}/${repo}.git ${repo}.git
    cd /tmp/${repo}.git
    # Shift off master to appropriate branch (if possible)
    git ls-remote --heads --exit-code origin ${WTSI_NPG_BUILD_BRANCH} && git pull origin ${WTSI_NPG_BUILD_BRANCH} && echo "Switched to branch ${WTSI_NPG_BUILD_BRANCH}"
    repos=$repos" /tmp/${repo}.git"
done

# Finally, bring any common dependencies up to the latest version and
# install
for repo in $repos
do
    cd $repo
    cpanm --quiet --notest --installdeps . || find /home/travis/.cpanm/work -cmin -1 -name '*.log' -exec tail -n20  {} \;		
    perl Build.PL
    ./Build		
    ./Build install
done

cd $TRAVIS_BUILD_DIR
