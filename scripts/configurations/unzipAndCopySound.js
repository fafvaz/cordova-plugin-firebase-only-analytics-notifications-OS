"use strict";

var path = require("path");
var AdmZip = require("adm-zip");

var utils = require("./utilities");

var constants = {
  pushSound: "push_sound"
};

module.exports = function(context) {
  var cordovaAbove8 = utils.isCordovaAbove(context, 8);
  var defer;
  if (cordovaAbove8) {
    defer = require('q').defer();
  } else {
    defer = context.requireCordovaModule("q").defer();
  }
  
  var platform = context.opts.plugin.platform;
  var platformConfig = utils.getPlatformConfigs(platform);
  if (!platformConfig) {
    utils.handleError("Invalid platform", defer);
  }
  
  var wwwPath = utils.getResourcesFolderPath(context, platform, platformConfig);
  
  var soundZipFile = utils.getZipFile(wwwPath, constants.pushSound);
  if (!soundZipFile) {
    console.log("No zip file found containing sound files");
    return;
  }

  var zip = new AdmZip(soundZipFile);

  var targetPath = path.join(wwwPath, constants.pushSound);
  zip.extractAllTo(targetPath, true);

  var files = utils.getFilesFromPath(targetPath);
  var soundFile = files.filter(x => path.basename(x) === platformConfig.soundFileName)[0];

  if (!soundFile) {
    console.log("No sound file found");
    return defer.promise;
  }
  
  var destFolder = platformConfig.getSoundDestinationFolder(context);
  utils.createOrCheckIfFolderExists(destFolder);
  
  var sourceFilePath = path.join(targetPath, path.basename(soundFile))
  var destFilePath = path.join(destFolder, path.basename(soundFile));
  
  utils.copyFromSourceToDestPath(defer, sourceFilePath, destFilePath);
  
  return defer.promise;
}