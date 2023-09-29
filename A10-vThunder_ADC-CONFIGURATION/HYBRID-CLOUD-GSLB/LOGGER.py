# -*- coding: utf-8 -*-
"""
A customised logger for this project for logging to the file and console
Created on 29/07/2022
@author: PNimbhore
"""
# imports
import os
import logging


class Logger:
    """
    A custom logger which will take care
    of logging to console and file.
    """
    def __init__(self, filepath):
        """
        Constructor
        :param filepath:
        """
        self.filepath = filepath
        self.logger = logging.getLogger('util')
        self.logger.setLevel(logging.DEBUG)
        self._formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        # file handler
        file_handller = logging.FileHandler(os.path.join(self.filepath), 'a')
        file_handller.setLevel(logging.DEBUG)
        file_handller.setFormatter(self._formatter)
        self.logger.addHandler(file_handller)
        # console handler
        con_handler = logging.StreamHandler()
        con_handler.setLevel(logging.ERROR)
        con_handler.setFormatter(self._formatter)
        self.logger.addHandler(con_handler)


log_file = "slb_config.log"
logger = Logger(log_file).logger
