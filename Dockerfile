# #### BASE-PYTHON-POETRY ####
# has python and poetry installed
# would push this part to a registry
FROM python:3.9 as base-python-poetry

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    POETRY_VERSION=1.1.13 \
    POETRY_HOME="/opt/poetry" \
    PYTHONPATH=/application_root \
    VIRTUAL_ENVIRONMENT_PATH="/venvs/venv"

ENV PATH="$POETRY_HOME/bin:$VIRTUAL_ENVIRONMENT_PATH/bin:$PATH"

# new installer for poetry, "install-poetry.py" instead of old "get-poetry.py"
# https://python-poetry.org/docs/master/#installing-with-the-official-installer
RUN curl -sSL https://install.python-poetry.org | python3 -

# create virtual environment that will serve as base for all other installs
RUN python3 -m venv $VIRTUAL_ENVIRONMENT_PATH


# #### BASE-IMAGE #### #
# has non-dev python requirements installed
# would actually pull from registry rather than base-python-poetry in same file
FROM base-python-poetry as base-image
WORKDIR /application_root

# install [tool.poetry.dependencies]
# activate virtual environment first so poetry installs there
COPY ./poetry.lock ./pyproject.toml /application_root/
RUN ["/bin/bash", "-c", "source $VIRTUAL_ENVIRONMENT_PATH/bin/activate && poetry install --no-interaction --no-root --no-dev"]


# #### DEVELOPMENT-IMAGE #### #
FROM base-image as development-image

# seems to help VS Code find the virtual environment even if venv wasn't made by poetry
ENV POETRY_VIRTUALENVS_PATH="/venvs"

# install [tool.poetry.dev-dependencies]
# activate virtual environment first so poetry installs there
RUN ["/bin/bash", "-c", "source $VIRTUAL_ENVIRONMENT_PATH/bin/activate && poetry install --no-interaction --no-root"]

COPY . /application_root/
# alternatively, you can set a volume mount to /application_root/

CMD ["/bin/bash"]


# #### PRODUCTION-IMAGE #### #
# uses a smaller version of python image and doesn't need poetry
# instead copies venv from base-image
FROM python:3.9-slim as production-image

WORKDIR /application_root
ENV PYTHONPATH=/application_root \
    VIRTUAL_ENVIRONMENT_PATH="/venvs/venv"

# assumes base-image created venv in a folder in this location
COPY --from=base-image /venvs /venvs

# copies only application code required for production
COPY ./app /application_root/app/

# TODO
# somehow need to make a script that activates the venv copied above
# now folder is /venvs/venv

CMD ["/bin/bash"]
