# minimal-py-poetry

Trying to make a nice multi-stage docker build that leverages poetry for building environment, has poetry available for a development stage, but keeps production stage to a small size by only copying the virtual environment that poetry created.

## The problem

Poetry is useful to manage dependencies; however, Poetry itself is not necessary as part of a production image (only the environment that it created is needed in production).
Docker multi- stage builds allow for the usage of poetry in development stages while allowing for a production stage without poetry if the virtual environment is copied from a separate stage.
Unfortunately poetry makes that complicated because it does not give complete control over the naming scheme of the virtual environment.

### Poetry virtual env handling

1. if a virtual environment is activated, poetry installs there
2. otherwise, if `POETRY_VIRTUALENVS_IN_PROJECT=true`, poetry installs to a folder inside project root called `.venv`
3. otherwise, poetry installs to directory at `POETRY_VIRTUALENVS_PATH` and creates a slug name for the folder (sort of like "app-root-dir-name-\<some sLuGoFchArs\>-py3.x"), which is difficult to reference later

#### Downsides

1. virtual env has to be created another way, then activated before using poetry to install dependencies
2. installing the venv into project root usually conflicts with mapping a volume to that root when developing inside docker containers (i.e. mapped volumes "overwrite" whatever may have existed in directory originally)
3. the production version of the application will have a hard time copying from this location since the name of the environment cannot be controlled

#### Approach ideas (going with the options above)

1. Use python `venv` to create a virtual environment somewhere outside of anywhere mapped volumes might go. Activate it, then run `poetry install` to install into that venv. Ensure the environment is activated for development and production.
2. Have poetry install into project root. Afterwards move `.venv` to a specific location outside of anywhere mapped volumes might go. (probably need to remove the environment variable that controlls install in root or poetry may default to trying that first when adding future dependencies). Ensure `.venv` is activated for development and production.
3. Really not sure how to work with this behavior in this way with multi-stage builds.
