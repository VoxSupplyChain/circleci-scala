FROM docker:1.13.1-git

RUN apk update && apk add --update python 
RUN curl https://bootstrap.pypa.io/get-pip.py | python
RUN pip install awscli
