# JupyterLab Container Image
# Used for providing prerequisites (i.e. we provide this image instead of having to install the prerequisites for each instance)

# Default image
ARG JUPYTERLAB_IMAGE="jupyter/minimal-notebook:lab-3.2.9"
FROM "${JUPYTERLAB_IMAGE}"

# Install prerequisites (node, ijavascript, client modules)
COPY *.whl *.tgz /home/jovyan/work/
ARG NODE_VERSION="14.18.3"
RUN mamba install --yes make cxx-compiler nodejs=${NODE_VERSION} \
    && npm install -g ijavascript \
    && ijsinstall \
    && cd /home/jovyan/work \
    && /opt/conda/bin/python -m pip install *.whl \
    && npm install -g --only=prod *.tgz \
    && rm *.whl *.tgz
