python3.10 -m venv create_layer
source create_layer/bin/activate
# For ARM64
# pip install -r requirements.txt --platform=manylinux2014_aarch64 --only-binary=:all: --target ./create_layer/lib/python3.10/site-packages
pip install -r requirements.txt