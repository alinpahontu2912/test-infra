#!/usr/bin/env bash

exit_if_not_on_git_tag() {
    # Have an override for debugging purposes
    if [[ -n "${TEST_WITHOUT_GIT_TAG-}" ]] ;then
        >&2 echo "+ WARN: Continuing without being on a git tag"
        exit 0
    fi
    # Exit if we're not currently on a git tag
    if ! git describe --tags --exact >/dev/null 2>/dev/null; then
        >&2 echo "- ERROR: Attempting to promote on a non-git tag, must have tagged current commit locally first"
        exit 1
    fi
    # Exit if we're currently on an RC
    if git describe --tags | grep "-rc" >/dev/null 2>/dev/null; then
        >&2 echo "- ERROR: Attempting to promote on a non GA git tag, current tag must be a GA tag"
        >&2 echo "         Example: v1.5.0"
        exit 1
    fi
}

get_pytorch_version() {
    if [[ -n "${TEST_WITHOUT_GIT_TAG-}" ]];then
        if  [[ -z "${TEST_PYTORCH_PROMOTE_VERSION-}" ]]; then
            >&2 echo "- ERROR: Specified TEST_WITHOUT_GIT_TAG without specifying TEST_PYTORCH_PROMOTE_VERSION"
            >&2 echo "-        TEST_PYTORCH_PROMOTE_VERSION must be specified"
            exit 1
        else
            echo "${TEST_PYTORCH_PROMOTE_VERSION}"
            exit 0
        fi
    fi
    exit_if_not_on_git_tag
    # Echo git tag, strip leading v
    git describe --tags | sed -e 's/^v//'
}

aws_promote() {
    package_name=$1
    pytorch_version=$(get_pytorch_version)
    # Dry run by default
    DRY_RUN=${DRY_RUN:-enabled}
    DRY_RUN_FLAG="--dryrun"
    if [[ $DRY_RUN = "disabled" ]]; then
        DRY_RUN_FLAG=""
    fi
    AWS=${AWS:-aws}
    (
        set -x
        ${AWS} s3 cp ${DRY_RUN_FLAG} \
            --acl public-read \
            --recursive \
            --exclude '*' \
            --include "*${package_name}-${pytorch_version}*" \
            "${PYTORCH_S3_FROM/\/$//}" \
            "${PYTORCH_S3_TO/\/$//}"
    )
    # ^ We grep for package_name-.*pytorch_version to avoid any situations where domain libraries have
    #   the same version on our S3 buckets
}
