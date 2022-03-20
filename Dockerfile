# #### BASE-PYTHON-POETRY ####
# has python and poetry installed
# would push this part to a registry
FROM python:3.9 as base-python-poetry

# poetry will respect POETRY_VIRTUALENVS_PATH as install location for venvs
# unless venv is already activated, in which case it will install there instead
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    POETRY_VERSION=1.1.13 \
    POETRY_HOME="/opt/poetry" \
    PYTHONPATH=/application_root \
    POETRY_VIRTUALENVS_PATH="/venvs" \
    VIRTUAL_ENVIRONMENT_PATH="/venvs/venv"

ENV PATH="$POETRY_HOME/bin:$VIRTUAL_ENVIRONMENT_PATH/bin:$PATH"

# https://python-poetry.org/docs/#osx--linux--bashonwindows-install-instructions
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        build-essential \
        curl \
    && curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py | python - \
    && apt-get purge --auto-remove -y \
      build-essential \
      curl

RUN python3 -m venv $VIRTUAL_ENVIRONMENT_PATH

# #### BASE-IMAGE #### #
# has non-dev python requirements installed
# would actually pull from registry rather than base-python-poetry in same file
FROM base-python-poetry as base-image
WORKDIR /application_root

# install [tool.poetry.dependencies]
COPY ./poetry.lock ./pyproject.toml /application_root/
RUN ["/bin/bash", "-c", "source $VIRTUAL_ENVIRONMENT_PATH/bin/activate && poetry install --no-interaction --no-root --no-dev"]


# #### DEVELOPMENT-IMAGE #### #
FROM base-image as development-image

# install [tool.poetry.dev-dependencies]
RUN ["/bin/bash", "-c", "source $VIRTUAL_ENVIRONMENT_PATH/bin/activate && poetry install --no-interaction --no-root"]

COPY . /application_root/
# alternatively, you can set a volume mount to /application_root/

CMD ["/bin/bash"]


# #### PRODUCTION-IMAGE #### #
# uses a smaller version of python image and doesn't need poetry
# instead copies venv from when poetry made it in base-image
FROM python:3.9-slim as production-image
WORKDIR /application_root

ENV PYTHONPATH=/application_root

# assumes base-image created venv in a folder in this location
COPY --from=base-image /venvs /venvs

# copies only application code required for production
COPY ./app /application_root/app/

# TODO
# somehow need to make a script that activates the venv copied above
# now folder is /venvs/venv

CMD ["/bin/bash"]
