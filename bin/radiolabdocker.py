import os.path as op
from os import makedirs
from radiolabdocker.BuildImage import buildIMAGE, buildSeq
from radiolabdocker.CreateContainer import makeCompose, createContainer
from radiolabdocker.CheckStat import checkContainerStat, checkImageStat


import datetime
seq = buildSeq('./SRC/radiolab_build_config/radiolab_build_seq.json', 'docker', 'latest')
args = {"ALL_PROXY": "172.29.0.1:1080"}
conf_path = './SRC/radiolab_build_config/radiolab_img_config.json'
log_dir = "./build/log"
dist = './build/Dockerfiles/'
rebuild = True

for base, tags in seq.items():
    for tag in tags:
        exist, img_tags = checkImageStat("radiolab_" + base)
        tag = int(tag) if tag != 'latest' else tag
        if exist:
            img_tags = [ int(t) for t in img_tags if t != 'latest']
            if tag == 'latest':
                if rebuild == True:
                    tag = int(datetime.datetime.now().strftime('%Y%m%d'))
                else:
                    tag = max(img_tags)
            elif tag in img_tags:
                tag = tag
            else:
                raise Exception("the tag {tag} for {base} is not valid, please check the build_seq.json file".format(tag = tag, base = base))
        retry = -1
        while not exist or tag not in img_tags:
            retry += 1
            if not op.exists(log_dir):
                makedirs(log_dir)
            if not op.exists(dist):
                makedirs(dist)
            buildIMAGE(conf_path, dist, base, args, log_dir).build()
            exist, img_tags = checkImageStat("radiolab_" + base)
            if retry > 5:
                break

mount = '~/Downloads'
jupyter_port = 8888
fs_license = './build/tmp/license.txt'
radiolabdocker_name = 'radiolab_docker_xpra'
radiolabdocker_img = 'radiolab_docker_xpra'
compose_src = './SRC/radiolab_xpra_compose/docker-compose.yml'
compose_dist = './build/tmp/radiolab_xpra/docker-compose.yml'
a = makeCompose(mount, radiolabdocker_name, radiolabdocker_img, compose_src, compose_dist, jupyter_port, fs_license)
a.make()
b = createContainer(compose_dist)
b.create()

mount = '~/Downloads'
jupyter_port = 8888
fs_license = './build/tmp/license.txt'
radiolabdocker_name = 'radiolab_docker'
radiolabdocker_img = 'radiolab_docker'
compose_src = './SRC/radiolab_docker_compose/docker-compose.yml'
compose_dist = './build/tmp/radiolab_docker/docker-compose.yml'
a = makeCompose(mount, radiolabdocker_name, radiolabdocker_img, compose_src, compose_dist, jupyter_port, fs_license)
a.make()
b = createContainer(compose_dist)
b.create()

check_container = 'radiolab_xpra'
checkContainerStat(check_container)
