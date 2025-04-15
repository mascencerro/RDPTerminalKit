#!/bin/sh

# This script creates a local mirror of Alpine packages to reduce outbound traffic
# If client is unable to get file (excluding modified packages) from local mirror it should continue to try remote repositories

apklist="alpine_apk.list"
mod_apklist="mod_apk.list"
failure_list="failed.list"
version="v3.21"
arch="x86_64"
repo_url="http://dl-cdn.alpinelinux.org/alpine/${version}"
local_base="/srv/www/alpine/${version}"

# Remove stale failed download list
rm "${local_base}/${failure_list}"

mkdir -p "${local_base}/main/${arch}"
mkdir -p "${local_base}/community/${arch}"

# Function to download each file
get_file() {
    section="${1}"
    file_name="${2}"
    url_string="${repo_url}/${section}/${file_name}"
    wget_result="$(wget -S ${repo_url}/${section}/${file_name} --directory-prefix=${local_base}/${section}/ 2>&1 | grep 'HTTP/' | awk '{print $2}')"

}

# Iterate through apklist
while IFS= read -r file_name; do
    echo "Downloading file: ${file_name}"
    section="main/${arch}"

    get_file ${section} ${file_name}

    # If file wasn't found in specified main repository, check community
    if [ "${wget_result}" != "200" ]; then
        echo "Failed to locate file ${file_name} in main. Trying community"
        section="community/${arch}"

        get_file ${section} ${file_name}
        
        # If file wasn't found in community, check mod_apklist (file may be one of the custom compiled packages)
        if [ "${wget_result}" != "200" ]; then
            echo "Failed to locate file ${file_name} in community. Skipping"

            # If file isn't listed in mod_apklist add to failed list
            if [ $(cat "${local_base}/${mod_apklist}" | grep -c "${file_name}") -eq 0 ]; then
                echo "${file_name}" >> "${failure_list}"

            fi

        else
            echo "File ${file_name} located in community."

        fi
    else
        echo "File ${file_name} located in main."
        
    fi

done < "${local_base}/${apklist}"

# Download indexes for main and community
wget "${repo_url}/main/${arch}/APKINDEX.tar.gz" --directory-prefix="${local_base}/main/${arch}/"
wget "${repo_url}/community/${arch}/APKINDEX.tar.gz" --directory-prefix="${local_base}/community/${arch}/"

