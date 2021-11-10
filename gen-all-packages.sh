#! /bin/bash -e
# generate all deb packages into packages subdir
# assumes that dpkg-deb is installed (install dpkg package?)
mkdir -p packages
rm packages/*.deb || true

for d in *; do
    if [[ -f "$d/gen-package.sh" ]]; then
        echo "===== Generating package for $d"
        (cd "$d"; ./gen-package.sh)
    fi
done

echo "===== Packages generated:"
/bin/ls -lh packages/*.deb
