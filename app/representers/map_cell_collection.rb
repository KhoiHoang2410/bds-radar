# Wrapper so MapCellsRepresenter can render { "cells": [ ... ], "precision": n }.
MapCellCollection = Struct.new(:cells, :precision, keyword_init: true)
