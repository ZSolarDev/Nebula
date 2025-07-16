# Nebula
A 3D renderer for HaxeFlixel

## URGENT:
- [X] Make N3DView actually produce visual output
- [X] Get proper frustum culling implemented
- [ ] Get near/far plane clipping implemented instead of simply regecting triangles close to the camera
## TODO:
- [ ] Fix the OBJ Loader
- [ ] Make an FBX Loader
- [ ] Make a GLTF Loader
- [ ] Make an MD2 Loader
- [ ] Make an MD3 Loader

## POSSIBILITIES:
- [ ] Make a DAE Loader

# NebulaTracer

## URGENT:
- [ ] Make Embree externs for hashlink
## TODO:
- [ ] When complete, make a simple tutorial here on how to use NebulaTracer in the main docs for NebulaTracer
- [ ] Make a json format that can be parsed by the externs to put configuration in
- [ ] Define a JSON format for geometry that the externs can parse

## EMBREE TODO:
- [X] Make the externs for Embree/hashlink
- [ ] Make the externs for Embree/hxcpp
- [ ] Integrate with Nebula
    - [X] Make non-tracing functions
    - [X] Make single ray trace function
    - [ ] Make multi ray trace function
    - [ ] Make smart multithreading

## OPTIX TODO:
- [ ] Make the externs for OptiX/hashlink
- [ ] Make the externs for OptiX/hxcpp
- [ ] Integrate with Nebula
    - [ ] Make non-tracing functions
    - [ ] Make ray trace functions

## DirectX Raytracer TODO:
- [ ] Make the externs for DirectX/hashlink
- [ ] Make the externs for DirectX/hxcpp
- [ ] Integrate with Nebula
