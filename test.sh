#!/bin/bash

source shtest/test.sh

function create_repo() {
    mkdir $1
    cd $1
    git init .
    echo "some lines" > README
    git add .
    git commit --all -m 'Initial commit'
    cd ..
}

function setup() {
    rm -rf $GIT_POOL_HOME
    create_repo project > /dev/null
    mkdir work
    cd work
}

function CloneNewRepoWithoutPathTest() {
    expect git pool clone `pwd`/../project
    cd project/.git/objects
    expect [[ `pwd -P` == "$GIT_POOL_HOME/project/.git/objects" ]]
    expect [[ `git pool list` == "project" ]]
}

function CloneNewRepoWithPathTest() {
    expect git pool clone `pwd`/../project work
    cd work/.git/objects
    expect [[ `pwd -P` == "$GIT_POOL_HOME/work/.git/objects" ]]
    expect [[ `git pool list` == "work" ]]
}

function ClonePooledRepoWithoutPathTest() {
    pushd ../project > /dev/null
    local realpath=`pwd`
    popd > /dev/null

    expect git pool clone $realpath
    chmod -R -w "$GIT_POOL_HOME/project"
    mkdir test
    cd test

    expect git pool clone $realpath
    chmod -R +w "$GIT_POOL_HOME/project"
    cd project/.git/objects
    expect [[ `pwd -P` == "$GIT_POOL_HOME/project/.git/objects" ]]
    expect [[ `git pool list` == "project" ]]
}

function ClonePooledRepoWithPathTest() {
    pushd ../project > /dev/null
    local realpath=`pwd`
    popd > /dev/null

    expect git pool clone $realpath
    chmod -R -w "$GIT_POOL_HOME/project"
    mkdir test
    cd test

    expect git pool clone $realpath work
    chmod -R +w "$GIT_POOL_HOME/project"
    cd work/.git/objects
    expect [[ `pwd -P` == "$GIT_POOL_HOME/project/.git/objects" ]]
    expect [[ `git pool list` == "project" ]]
}

function MirrorNonPooledRepoTest() {
    expect git pool clone `pwd`/../project
    git pool mirror nonexistent
    expect [[ ! $? -eq 0 ]]
    expect [[ ! -d nonexistent ]]
}

function MirrorPooledRepoTest() {
    pushd ../project > /dev/null
    local realpath=`pwd`
    popd > /dev/null

    expect git pool clone $realpath
    expect git pool mirror project work
    expect [[ -d work ]]
    cd work/.git/objects
    expect [[ `pwd -P` == "$GIT_POOL_HOME/project/.git/objects" ]]
    expect [[ `git pool list` == "project" ]]
}

function MirroredRepoHasSeparateIndexTest() {
    expect git pool clone `pwd`/../project

    cd project
    echo "something is definitely changing" >> README
    expect git status --porcelain | grep README

    cd $GIT_POOL_HOME/project
    expect [[ `git status --porcelain` == "" ]]
}

function CommitInMirroredRepoIsSyncedTest() {
    expect git pool clone `pwd`/../project

    cd project
    echo "something is definitely changing" >> README
    git commit -am 'Modifying README'

    local hash=`git rev-parse HEAD`

    cd $GIT_POOL_HOME/project
    expect [[ `git rev-parse HEAD` == $hash ]]
}

function ChangingBranchInMirroredRepoIsNotSyncedTest() {
    cd ../project
    git checkout -b other-branch
    git checkout master
    cd ../work

    expect git pool clone `pwd`/../project

    cd project
    git checkout other-branch
    local branch=`git rev-parse --abbrev-ref HEAD`

    cd $GIT_POOL_HOME/project
    expect [[ `git rev-parse --abbrev-ref HEAD` != $branch ]]
    expect [[ `git rev-parse --abbrev-ref HEAD` == "master" ]]
}

function CommitInMirroredRepoOnAnotherBranchIsSyncedTest() {
    cd ../project
    git checkout -b other-branch
    git checkout master
    cd ../work

    expect git pool clone `pwd`/../project

    cd project
    git checkout other-branch
    echo "something is definitely changing" >> README
    git commit -am "Modifying README"

    local hash=`git rev-parse HEAD`

    cd $GIT_POOL_HOME/project
    git checkout other-branch
    expect [[ `git rev-parse HEAD` == $hash ]]
}

#function RelinkInvalidRepoMirrorsCurrentTest() {
#}

function RelinkToTheSameDoesNothingTest() {
    expect git pool clone `pwd`/../project
    expect git pool relink project `pwd`/../project

    cd project
    expect [[ `git status --porcelain` == "" ]]
    cd .git/objects
    expect [[ `pwd -P` == "$GIT_POOL_HOME/project/.git/objects" ]]
}

function RelinkToAForkTest() {
    local dir=`mktemp -d`

    # Fork repo
    cp -R ../project $dir/project

    expect git pool clone `pwd`/../project
    expect git pool clone $dir/project project2
    expect git pool relink project $dir/project

    cd project/.git/objects
    expect [[ `pwd -P` == "$GIT_POOL_HOME/project2/.git/objects" ]]
}

function RelinkDoesNotDiscardWorkTest() {
    local dir=`mktemp -d`

    # Fork repo
    cp -R ../project $dir/project

    expect git pool clone `pwd`/../project
    expect git pool clone $dir/project project2

    cd project
    echo "something changing" >> README
    cd ..

    expect git pool relink project $dir/project
    cd project
    expect git status --porcelain | grep README
}

function CloneForkedRepoWithPathWillRotateNameTest() {
    local dir=`mktemp -d`
    local dir2=`mktemp -d`

    # Fork repo
    cp -R ../project $dir/project
    cp -R ../project $dir2/project

    expect git pool clone `pwd`/../project project
    mkdir work
    cd work
    expect git pool clone $dir/project project

    cd project/.git/objects

    expect [[ `pwd -P` == "$GIT_POOL_HOME/project-0/.git/objects" ]]
    expect git pool list | grep 'project-0'

    mkdir ../work2
    cd ../work2
    expect git pool clone $dir2/project project

    cd project/.git/objects

    expect [[ `pwd -P` == "$GIT_POOL_HOME/project-1/.git/objects" ]]
    expect git pool list | grep 'project-1'
}

function CloneForkedRepoWithoutPathWillRotateNameTest() {
    local dir=`mktemp -d`
    local dir2=`mktemp -d`

    # Fork repo
    cp -R ../project $dir/project
    cp -R ../project $dir2/project

    expect git pool clone `pwd`/../project
    mkdir work
    cd work
    expect git pool clone $dir/project

    cd project/.git/objects

    expect [[ `pwd -P` == "$GIT_POOL_HOME/project-0/.git/objects" ]]
    expect git pool list | grep 'project-0'

    mkdir ../work2
    cd ../work2
    expect git pool clone $dir2/project

    cd project/.git/objects

    expect [[ `pwd -P` == "$GIT_POOL_HOME/project-1/.git/objects" ]]
    expect git pool list | grep 'project-1'
}

function DisablePoolsAndCloneRepositoryTest() {
    local orig_disabled=`git config --global --bool --get pool.disabled`
    if [ "$orig_disabled" == "" ]; then
        orig_disabled="nonexistent"
    fi

    git config --global --bool pool.disabled true

    expect git pool clone `pwd`/../project
    cd project
    local d=`pwd -P`
    cd .git/objects
    expect [[ `pwd -P` == "$d/.git/objects" ]]
    expect [[ "`git pool list`" == "" ]]


    if [ $orig_disabled == "nonexistent" ]; then
        git config --global --remove-section pool
    else
        git config --global --bool pool.disabled $orig_disabled
    fi
}

pushd $(dirname $0) > /dev/null
SCRIPTPATH=$(pwd)
popd > /dev/null

export PATH=$SCRIPTPATH:$PATH

export GIT_POOL_HOME=`mktemp -d`

pushd $GIT_POOL_HOME > /dev/null
GIT_POOL_HOME=`pwd -P`
popd > /dev/null

local disabled=`git config --global --bool --get pool.disabled`

git config --global --bool pool.disabled false

run_tests "$1"

if [ "$disabled" == "" ]; then
    git config --global --remove-section pool
else
    git config --global --bool poll.disabled $disabled
fi
