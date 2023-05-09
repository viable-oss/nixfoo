{ stdenv, lib, python3Packages, aiohttp-utils, ... }:

with python3Packages;
buildPythonPackage rec {
  pname = "swh-core";
  version = "2.22.0";

  src = fetchPypi {
    inherit version;
    pname = "swh.core";
    sha256 = "sha256-y7jehR53jNdM0L625BlpRurRvoHDl4k/sgXZrT48p6A=";
  };

  # Tests require network access.
  doCheck = false;

  propagatedBuildInputs = [
    click
    deprecated
    pyyaml
    python-magic
    sentry-sdk

    # swh.core.db
    psycopg2
    typing-extensions

    # swh.core.github
    tenacity
    requests

    # swh.core.api
    aiohttp
    aiohttp-utils
    blinker
    flask
    iso8601
    msgpack

    setuptools-scm
  ];

  meta = with lib; {
    description = "Software Heritage filesystem";
    homepage = "https://www.softwareheritage.org/";
    license = licenses.gpl3Only;
  };
}
