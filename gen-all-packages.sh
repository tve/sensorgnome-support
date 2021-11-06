#! /bin/bash -e
# generate all deb packages into packages subdir
# assumes that dpkg-deb is installed (install dpkg package?)
mkdir -p packages
rm packages/*.deb || true

for d in */ ; do
    if [[ -d "$d" ]]; then
        cd "$d"
        if [ -f "gen_package.sh" ]; then
            echo "===== Generating package for $d"
            ./gen_package.sh
        fi
        cd ..
    fi
done

echo "===== Packages generated:"
/bin/ls -lh packages/*.deb
