# JupyterLab Container Image
# Used for providing prerequisites (i.e. we provide this image instead of having to install the prerequisites for each instance)

# Default image
ARG JUPYTERLAB_IMAGE="jupyter/minimal-notebook:lab-3.4.3"
FROM "${JUPYTERLAB_IMAGE}"

# Install prerequisites (node, ijavascript, client modules)
COPY *.whl *.tgz /home/jovyan/work/
ARG NODE_VERSION="16"
RUN mamba install --yes make cxx-compiler zeromq nodejs=${NODE_VERSION} \
    && npm install -g ijavascript \
    && ijsinstall \
    && cd /home/jovyan/work \
    && /opt/conda/bin/python -m pip install *.whl pandas matplotlib ipywidgets \
    && /opt/conda/bin/jupyter nbextension enable --py widgetsnbextension \
    && npm install -g --only=prod *.tgz \
    && rm *.whl *.tgz
