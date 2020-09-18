# docker-smartmet-cibase-8
A docker image as a base for CI machinery builds and test on CentOS 8.

## Changes/additions compared to basic CentOS

All smartmet RPM packages could be built on a minimal CentOS system although you would need some extra repositories
in most cases. Also, to really build agains the most recent libraries and compilers, with all security patches, you would need
to update the minimal system first.

In order to faciliate this process somewhat, this image was created. In addition to basic CentOS+updates, it includes:
* all available updates (rebuilt daily so fairly recent)
* EPEL repository enabled
* some FMI specific public repositories enabled
* some versionlocks required and/or workarounds discovered during builds of various modules (these are available on servers as well)
* some preinstalled packages which are practically always needed (such as make and sudo)
* some hooks for better experience in local building and shell mode
* ci-build wrapper tool (see below)

## Ci-build tool

This tool is intended to run inside the docker image actually responsible for building/testing.
It is fairly simple tool which merely manages some steps which are practically always needed when running
inside CI. These are, for example:
* detection of proxy when running inside FMI office network
* collecting of resulting RPM files to a standard dist-directory
* installation of test dependencies (using the #TestRequires -extension)
* collecting installed libraries so that they work when running make test
* running make test

The standard way to use to build using the tool:
* ci-build deps (install build dependencies)
* ci-build rpm (build and collect RPMs)

The standard way to test:
* install files under testing using sudo yum or other method (not performed by ci-build, has to be managed using normal commands)
* ci-build testprep (install any test dependencies)
* ci-build test (effectively run make test)

To restrict the amount of memory usage the amount of threads used during RPM build is limited. Tool should autodetect whether we
are running on real CircleCI servers and currently limits the amount of processes to three on them. 
By experience, it has been discovered, that increasing this number
will result in compiler errors in some modules. The value could be made configurable in future versions.

There are some other checks and workarounds for various issues discovered during CI processing. These may change and/or
added to in future versions. Check the comments inside ci-build.sh for more information

### Test step disable feature (hopefully temporary)

Currently, having a file disable-tests-in-ci inside .circleci directory of your source tree will disable tests.
I.e. ci-build test still runs but always returns success and won't do anything.
This is hopefully a short term solution. There are several modules which have non-working tests or tests that do not work
in CI environment. Long-term these should be fixed and at least a subset of the tests should run.

The existence of this file means that nobody has had time to go through the module and set all the needed dependencies and
work through the tests.
Having a single file to disable all tests was, for the time being, the easiest way to still let all jobs work in the same way.
It is also easy to find and remove - much easier than having workarounds in different Makefiles.

## Help functionality for local shell mode

There is a wrapper and some extra things done to make it more convenient to use the so called shell-mode on your local system.
The primary purpose of the shell mode would be test drive how build and/or tests work in the CI environment without actually
needing to install a separate CentOS system for that.

The purpose of all the wrappers is primarily to take care of possibly needed proxies and to run the shell and associated build processes as the same uid as you are on the host system. If there are any bind mounts (usually at least the working tree), and
you run the build process as superuser, you would have difficulties removing/rebuilding on host system. The uid wrapping tries to avoid such situations.

You can check how to use it effectively from smartmet-build-utils module.

