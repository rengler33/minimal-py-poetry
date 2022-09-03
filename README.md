# minimal-py-poetry

This is an attempt to make a nice multi-stage docker build that leverages poetry for building environment, has poetry available for a development stage, but keeps production stage to a small size by only copying the virtual environment that poetry created.

## The problem

Poetry is useful to manage dependencies; however, Poetry itself is not necessary as part of a production image (only the environment that it created is needed in production).

Docker multi-stage builds allow for the usage of poetry in build & development stages while allowing for a production stage without poetry if the virtual environment is copied from the build stage.

Unfortunately poetry makes that complicated because it does not give complete control over the naming scheme of the virtual environment.

## High-level Approach

1. Create a build stage (base build)
    1. Use python `venv` to create a virtual environment somewhere outside of anywhere mapped volumes might go.
    2. Poetry installs runtime deps to that virtual environment
2. Create a separate development image from base build
    1. poetry installs development dependencies to virtual environment
    2. poetry is available for future needs
3. Create a production image from a pred-prod stage
    1. In a pre-prod stage, create app skeleton and install the app as a package (symlink)
    2. Copy ONLY the virtual environment (containing only runtime dependencies) and app code to the production image

### Notes on poetry virtual env handling

Poetry doesn't give total control over

1. if a virtual environment is activated, poetry installs there
2. otherwise, if `POETRY_VIRTUALENVS_IN_PROJECT=true`, poetry installs to a folder inside project root called `.venv`
3. otherwise, poetry installs to directory at `POETRY_VIRTUALENVS_PATH` and creates a slug name for the folder (sort of like "app-root-dir-name-\<some sLuGoFchArs\>-py3.x"), which is difficult to reference later

The approach used in this `Dockerfile` relies on #1 (setting `VIRTUAL_ENV` so poetry installs there).
#2 is undesirable because we're often trying to mount the application code from local machine so it can't create the virtual environment without getting overshadowed by mount. Also don't want the virtual environment to be part of the build context.
#3 is difficult to copy to the production image from the builder stage due to the naming scheme that is not controllable.

## Running the example application

### Development

`docker compose build`
`docker compose up`

### Production

`docker build . -t app`
`docker run -it -p 0.0.0.0:8000:8000 app`
