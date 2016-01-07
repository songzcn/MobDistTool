import 'package:angular/angular.dart';
import 'package:angular_ui/angular_ui.dart';
import 'dart:convert';

class BaseComponent  implements ScopeAware {
  MainComponent mainComp(){
    return scope.parentScope.context;
  }
  Scope scope;
  bool isHttpLoading = false;
}



//Model
class MDTUser {
  String name;
  String email;
 // String externalTokenId;
  bool isSystemAdmin;
  MDTUser(Map map){
    name = map["name"];
    email = map["email"];
   // externalTokenId = map["externalTokenId"];
    isSystemAdmin = map["isSystemAdmin"];
  }
}


  class MDTApplication {
  String uuid;
  String apiKey;
  String name;
  String platform;
  String description;
  List<MDTUser> adminUsers;
  List<MDTArtifact> lastVersion;
  MDTApplication(Map map){
    uuid = map["uuid"];
    apiKey = map["apiKey"];
    name = map["name"];
    platform = map["platform"];
    description = map["description"];
    //admin user
    adminUsers = new List<MDTUser>();
    for (Map map in map["adminUsers"]){
        adminUsers.add(new MDTUser(map));
    }
    //last version
    lastVersion = new List<MDTArtifact>();
    for (Map map in map["lastVersion"]){
      lastVersion.add(new MDTArtifact(map));
    }
  }
}

class MDTArtifact{
  String uuid;
  String branch;
  String name;
  DateTime creationDate;
  MDTApplication application;
  String version;
  String sortIdentifier;
 // String storageInfos;
  Map metaDataTags;
  MDTArtifact(Map map){
    uuid = map["uuid"];
    branch = map["branch"];
    name = map["name"];
    creationDate = map["creationDate"];
    sortIdentifier = map["sortIdentifier"];
    metaDataTags = JSON.decode(map["metaDataTags"]);
  }
}