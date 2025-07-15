# Bazel Docs

Convert Bazel’s Devsite docs into a Hugo/Docsy site for easy modification.

## Motivation

This tool implements the improvements outlined in [Bazel Docs: Why It Might Be Time For A Refresh](https://alanmond.com/posts/bazel-documentation-improvements/).  The goal is to create a more developer friendly set of Bazel Docs.  Starting with [bazel.build/docs](https://bazel.build/docs)

## Live Demo

https\://bazel-docs-68tmf.ondigitalocean.app/

## How it works

1. Clones the Devsite source from `bazel.build/docs`.
2. Transforms Devsite frontmatter and directory layout into Hugo/Docsy format.
3. Converts CSS/SCSS for Docsy theme compatibility.

## Usage

Bash into the docker image to see the Hugo converted website:

```bash
docker run -it -p 1313:1313 alan707/bazel-docs:latest bash
```

Once inside, the generated Hugo site will be at the following location:

```bash
root@7feab7b056d2:/app/docs# ls -al /app/docs
total 52
drwxr-xr-x  1 root root 4096 Jul 15 05:53 .
drwxr-xr-x  1 root root 4096 Jul 15 05:53 ..
-rw-r--r--  1 root root    0 Jul 15 05:53 .hugo_build.lock
drwxr-xr-x  2 root root 4096 Jul 15 05:53 archetypes
drwxr-xr-x  3 root root 4096 Jul 15 05:53 assets
drwxr-xr-x 25 root root 4096 Jul 15 05:53 content
drwxr-xr-x  2 root root 4096 Jul 15 05:53 data
-rw-r--r--  1 root root   99 Jul 15 05:53 go.mod
-rw-r--r--  1 root root  394 Jul 15 05:53 go.sum
-rw-r--r--  1 root root 2527 Jul 15 05:53 hugo.yaml
drwxr-xr-x  2 root root 4096 Jul 15 05:53 i18n
drwxr-xr-x  2 root root 4096 Jul 15 05:53 layouts
drwxr-xr-x  3 root root 4096 Jul 15 05:53 resources
drwxr-xr-x 12 root root 4096 Jul 15 05:53 static
```

To test your changes, you can convert the Bazel Docs Devsite into a Hugo website running this command
```bash
root@7feab7b056d2:/app# python /app/cli.py convert --source /app/work/bazel-source/site/en/ --output /app/docs/
```

Add the modules needed (mainly Docsy)
```bash
cd /app/docs
hugo mod init github.com/alan707/bazel-docs && \
    hugo mod get github.com/google/docsy@v0.12.0 && \
    hugo mod tidy
```

Generate static files and start the Hugo server
```bash
cd /app/docs
hugo --destination /workspace/public
hugo server --bind 0.0.0.0 --baseURL "http://localhost:1313"
```
