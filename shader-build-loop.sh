#!/usr/bin/env bash

while : ; do
  inotifywait -e close_write ./src/shaders/compute.slang &>/dev/null
  slangc src/shaders/compute.slang -target spirv -profile spirv_1_4 \
  -emit-spirv-directly -fvk-use-entrypoint-name -entry compRender \
  -fvk-use-entrypoint-name -entry compUpdate \
  -o src/shaders/comp.spv || continue
done
