git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch test/data/conv1_diff.bin' --prune-empty --tag-name-filter cat -- --all

rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=new

# check space
du ./ -d 1 -h
