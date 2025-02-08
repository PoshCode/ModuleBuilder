VERSION 0.8
IMPORT github.com/poshcode/tasks
FROM mcr.microsoft.com/dotnet/sdk:9.0
WORKDIR /work

ARG --global EARTHLY_GIT_ORIGIN_URL
ARG --global EARTHLY_BUILD_SHA
ARG --global EARTHLY_GIT_BRANCH
# These are my common paths, used in my shared /Tasks repo
ARG --global OUTPUT_ROOT=/Modules
ARG --global TEST_ROOT=/Tests
ARG --global TEMP_ROOT=/temp
# These are my common build args, used in my shared /Tasks repo
ARG --global MODULE_NAME=ModuleBuilder
ARG --global CONFIGURATION=Release


bootstrap:
    # Dotnet tools and scripts installed by PSGet
    ENV PATH=$HOME/.dotnet/tools:$HOME/.local/share/powershell/Scripts:$PATH
    RUN mkdir /Tasks \
        && git config --global user.email "Jaykul@HuddledMasses.org" \
        && git config --global user.name "Earthly Build"
    # I'm using Invoke-Build tasks from this other repo which rarely changes
    COPY tasks+tasks/* /Tasks
    # Dealing with dependencies first allows docker to cache packages for us
    # So the dependency cach only re-builds when you add a new dependency
    COPY build.requires.psd1 .
    # COPY *.csproj .
    RUN ["pwsh", "-File", "/Tasks/_Bootstrap.ps1", "-RequiresPath", "build.requires.psd1"]

build:
    FROM +bootstrap
    RUN mkdir $OUTPUT_ROOT $TEST_ROOT $TEMP_ROOT
    COPY . .
    # make sure you have bin and obj in .earthlyignore, as their content from context might cause problems
    RUN ["pwsh", "-Command", "Invoke-Build", "-Task", "Build", "-File", "Build.build.ps1"]

    # SAVE ARTIFACT [--keep-ts] [--keep-own] [--if-exists] [--force] <src> [<artifact-dest-path>] [AS LOCAL <local-path>]
    SAVE ARTIFACT $OUTPUT_ROOT/$MODULE_NAME AS LOCAL ./Modules/$MODULE_NAME

test:
    # If we run a target as a reference in FROM or COPY, it's outputs will not be produced
    FROM +build
    # make sure you have bin and obj in .earthlyignore, as their content from context might cause problems
    RUN ["pwsh", "-Command", "Invoke-Build", "-Task", "Test", "-File", "Build.build.ps1"]

    # re-output the build output so we can rely on running just +test locally
    SAVE ARTIFACT $OUTPUT_ROOT/$MODULE_NAME AS LOCAL ./Modules/$MODULE_NAME
    SAVE ARTIFACT $TEST_ROOT AS LOCAL ./Modules/$MODULE_NAME-TestResults

all:
    BUILD +build
    BUILD +test
    FROM +build
    RUN --push --secret NUGET_API_KEY --secret PSGALLERY_API_KEY -- \
        pwsh -Command Invoke-Build -Task Push -File Build.build.ps1 -Verbose
