# Enable long-path and restart: https://mspoweruser.com/ntfs-260-character-windows-10/

Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install golang
choco install git

# RESTART POWERSHELL

git config --global user.email "user@domain.com"
git config --global user.name "Username"

# NOTE! Dependency restoration may change in different versions of Telegraf. Currently using GDM + Dep

$GO_SRC="C:\Users\$env:USERNAME\go\src"
$BASE_BUILD_TAG="1.9.0"

# GDM
go get -v github.com/sparrc/gdm
cd $GO_SRC\github.com/sparrc/gdm
go build

# Dep
go get -u github.com/golang/dep/cmd/dep
cd $GO_SRC\github.com\golang\dep\cmd\dep
go build

# Get Telegraf
go get -v -d github.com/influxdata/telegraf
cd $GO_SRC\github.com\influxdata\telegraf

# Switch to desired tag
git checkout master
git reset --hard
git checkout $BASE_BUILD_TAG
$PARENT_COMMIT=$(git rev-parse --short HEAD)

# Apply patches

# NTLM from discarded PR
git fetch origin pull/2831/head:NTLM-Auth
git cherry-pick 594ae6dbe9e5f46571c8a25c845f9e8c1813fda1
git checkout HEAD Godeps
Add-Content -Path "Godeps" -Value "github.com/gropensourcedev/go-ntlm-auth 6314d66e1d8ffd12a8da4be59eb4467b60dde719"
git add Godeps
git commit -m "GR: Apply NTLM patch"

# Manually add rejected lower-case change to sanitize function
$OPEN_TSDB_OUTPUT=".\plugins\outputs\opentsdb\opentsdb.go"
(gc $OPEN_TSDB_OUTPUT) -Replace("allowedChars.ReplaceAllLiteralString\(value, ""_""\)",
"strings.ToLower(allowedChars.ReplaceAllLiteralString(value, ""_""))"
) | set-content $OPEN_TSDB_OUTPUT
git add $OPEN_TSDB_OUTPUT
git commit -m "GR: Lower-case all metrics"

# Restore dependencies and compile
gdm restore -v
dep ensure -vendor-only -v

go build -ldflags="-X main.version=$BASE_BUILD_TAG-GR -X main.commit=$PARENT_COMMIT -X main.branch=$BASE_BUILD_TAG" cmd\telegraf\telegraf.go
.\telegraf --version
