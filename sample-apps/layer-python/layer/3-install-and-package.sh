#!/bin/bash

echo "Step 1: Installing Python dependencies..."
# Create virtual environment
python3.10 -m venv create_layer
source create_layer/bin/activate

# Install dependencies
# For ARM64 (uncomment if needed)
# pip install -r requirements.txt --platform=manylinux2014_aarch64 --only-binary=:all: --target ./create_layer/lib/python3.10/site-packages
pip install -r requirements.txt

# Deactivate virtual environment
deactivate

echo "Step 2: Preparing for packaging..."
# Create the python directory for the layer structure
mkdir -p python

# Copy all libraries to the python directory
cp -r create_layer/lib/python3.10/site-packages/* python/

# Get the size of each top-level directory and sort them
echo "Step 3: Analyzing directory sizes..."
cd python

# Use files instead of associative arrays for better compatibility
rm -f /tmp/dir_sizes.txt 2>/dev/null
total_size=0

for dir in */; do
    # Remove trailing slash
    dir=${dir%/}
    # Skip if not a directory
    [ ! -d "$dir" ] && continue
    
    # Get size in KB
    size=$(du -sk "$dir" | cut -f1)
    echo "$dir $size" >> /tmp/dir_sizes.txt
    total_size=$((total_size + size))
    echo "$dir: $size KB"
done

cd ..

# Calculate target size per zip (20% of total)
target_size=$((total_size / 5))
echo "Total size: $total_size KB"
echo "Target size per zip: $target_size KB"

# Create 5 directories for splitting
for i in {1..5}; do
    mkdir -p "split$i/python"
done

# Distribute directories among the 5 splits using a greedy algorithm
echo "Step 4: Splitting directories into 5 parts..."

# Initialize split sizes file
for i in {1..5}; do
    echo "$i 0" >> /tmp/split_sizes.txt
done

# Sort directories by size (largest first)
sort -k2 -nr /tmp/dir_sizes.txt > /tmp/sorted_dirs.txt

# Assign each directory to the split with the smallest current size
while read dir size; do
    # Find the split with the smallest current size
    smallest_split=$(sort -k2 -n /tmp/split_sizes.txt | head -1 | cut -d' ' -f1)
    smallest_size=$(grep "^$smallest_split " /tmp/split_sizes.txt | cut -d' ' -f2)
    
    # Assign directory to the smallest split
    echo "Adding $dir ($size KB) to split$smallest_split"
    cp -r "python/$dir" "split$smallest_split/python/"
    
    # Update split size
    new_size=$((smallest_size + size))
    sed -i.bak "s/^$smallest_split .*/$smallest_split $new_size/" /tmp/split_sizes.txt
done < /tmp/sorted_dirs.txt

# Create zip files for each split
echo "Step 5: Creating zip files..."
for i in {1..5}; do
    split_size=$(grep "^$i " /tmp/split_sizes.txt | cut -d' ' -f2)
    echo "Creating layer_content_part$i.zip ($split_size KB)"
    cd "split$i"
    zip -r "../layer_content_part$i.zip" python
    cd ..
    # Clean up split directory
    rm -rf "split$i"
done

# Clean up the combined python directory and temp files
rm -rf python
rm -f /tmp/dir_sizes.txt /tmp/sorted_dirs.txt /tmp/split_sizes.txt /tmp/split_sizes.txt.bak

echo "Done! Created 5 layer zip files:"
for i in {1..5}; do
    ls -lh "layer_content_part$i.zip"
done

echo ""
echo "You can now deploy these as separate AWS Lambda layers."
echo "Each zip file contains a subset of your Python dependencies." 