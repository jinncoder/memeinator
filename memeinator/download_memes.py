#!/usr/bin/env python3
#
###############################################################################
#                                                                             #
# https://github.com/bhill298/memegen-offline/blob/main/download_memes_api.py #
#                                                                             #
###############################################################################

import json
import os
import pathlib
import re
import urllib.request

BASEPATH = pathlib.PosixPath(__file__).parent


def query_url_json(url):
    # returns a json object or None
    j = None
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req) as r:
            j = json.loads(r.read().decode(r.info().get_param("charset") or "utf-8"))
    except Exception as e:
        print(e)
        pass
    return j


def query_url(url):
    # returns a bytes object or None
    data = None
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req) as r:
            data = r.read()
    except Exception as e:
        print(e)
        pass
    return data


def filter_name(name):
    name = name.lower()
    name = name.replace(" ", "-")
    name = re.sub(r"[^a-zA-Z0-9_\-]+", "", name)
    return name


def download_memes(path):
    # top 100 memes from imgflip api
    memes = query_url_json("https://api.imgflip.com/get_memes")
    if memes is not None and memes["success"]:
        memes = memes["data"]["memes"]
        for meme in memes:
            ext = os.path.splitext(meme["url"])[1]
            filename = os.path.join(path, filter_name(meme["name"]) + ext)
            with open(filename, "wb") as f:
                dat = query_url(meme["url"])
                if dat is not None:
                    f.write(dat)
            print("Downloaded " + filename)

def entry():
    meme_template_path = BASEPATH / "static" / "meme_template"
    meme_template_path.mkdir(parents=True, exist_ok=True)

    download_memes(str(meme_template_path))

if __name__ == "__main__":
    entry()
