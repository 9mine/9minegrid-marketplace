This filesystem needs github token for proper functioning. Add this into helm values file:


        secrets:
            GITHUB_ACCESS_TOKEN: <Github Token>


Compiling from sources (requires [jinja2-cli](https://pypi.org/project/jinja2-cli/) to be installed.

    $ jinja2 src/values.yml -o values.yml