// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'package:option/option.dart';
//logging
import 'package:logging/logging.dart';
import 'package:logging_handlers/server_logging_handlers.dart';
//rpc
import 'package:rpc/rpc.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_static/shelf_static.dart' as shelf_static;
import 'package:shelf_rpc/shelf_rpc.dart' as shelf_rpc;
import 'package:shelf_route/shelf_route.dart' as shelf_route;
import 'package:shelf_cors/shelf_cors.dart' as shelf_cors;
import 'package:shelf_exception_handler/shelf_exception_handler.dart';
//authentication / authorisation
import 'package:shelf_auth/shelf_auth.dart';
import 'package:shelf_auth/src/authorisers/authenticated_only_authoriser.dart';

//server
import 'package:shelf/shelf_io.dart' as shelf_io;
//mongo DB
import '../server/config/src/mongo.dart' as mongo;
//config
import '../server/config/config.dart' as config;
//storage
import '../server/config/src/storage.dart' as storage;
//API
import '../server/managers/managers.dart';

import '../server/services/user_service.dart';
import '../server/services/application_service.dart';
import '../server/services/artifact_service.dart';
import '../server/services/in_service.dart';
import '../server/utils/utils.dart' as utils;

const _API_PREFIX = '/api';
/*const _SIGNED_PREFIX = _API_PREFIX+'/in';
const _AUTHORIZED_PREFIX = _API_PREFIX;
const _LOGIN_PREFIX = _API_PREFIX+'/users';*/

final ApiServer _apiServer = new ApiServer(apiPrefix: _API_PREFIX, prettyPrint: true);
//final ApiServer _statelessApiServer = new ApiServer(apiPrefix: _STATELESS_PREFIX, prettyPrint: true);

HttpServer httpServer;

Future stopServer({bool force:false}) async {
  await httpServer.close(force:true);
}

Future<HttpServer> startServer({bool resetDatabaseContent:false}) async {
  print ("MDT starting ...");
  await config.loadConfig();

  // Add a simple log handler to log information to a server side file.
  Logger.root.level = Level.WARNING;
  DateTime now = new DateTime.now();
  var logFile = "${config.currentLoadedConfig[config.MDT_LOG_DIR]}mdt_logs_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.txt";
  Logger.root.onRecord.listen(new SyncFileLoggingHandler(logFile));
  if (stdout.hasTerminal) {
    Logger.root.onRecord.listen(new LogPrintHandler());
  }
  print("logging file : $logFile");

  await mongo.initialize(dropCollectionOnStartup:resetDatabaseContent);

  await storage.initialize();

  //_apiServer.addApi(new ToyApi());
  _apiServer.addApi(new UserService());
  _apiServer.addApi(new ApplicationService());
  _apiServer.addApi(new ArtifactService());
  _apiServer.addApi(new InService());
  _apiServer.enableDiscoveryApi();

  //authentication
  var sessionHandler = new JwtSessionHandler('MobDistTool', '${utils.randomString(15)} secret', usernameLookup);
  var loginMiddleware = authenticate([new UsernamePasswordAuthenticator(authenticateUser)],
  sessionHandler:sessionHandler , allowHttp: true);

  var defaultAuthMiddleware = authenticate([],
  sessionHandler: sessionHandler, allowHttp: true,
  allowAnonymousAccess: false);

  var authenticatedMiddleware = authorise([new AuthenticatedOnlyAuthoriser()]);

  // Create a Shelf handler for your RPC API.
  var apiHandler = shelf_rpc.createRpcHandler(_apiServer);

  var staticHandler =  shelf_static.createStaticHandler('build/web',
      defaultDocument: 'index.html');

  var apiRouter = shelf_route.router()
      //disable authent for register
      ..add('api/users/v1/register',null,apiHandler,exactMatch: false)
      ..get('api/in/v1/artifacts/{artifactid}/file{?token}',(request) => ArtifactService.downloadFile(shelf_route.getPathParameter(request, 'artifactid'),token: shelf_route.getPathParameter(request, 'token')))
      ..add('/api/in/',null,apiHandler,exactMatch: false)
      ..add('api/users',['GET','POST'],apiHandler,exactMatch: false,middleware: loginMiddleware)
      //..add(_SIGNED_PREFIX,null,apiHandler,exactMatch: false,middleware:authenticatedMiddleware)
      //disable authent for discovery ?
      ..add('api/discovery',null,apiHandler,exactMatch: false)
      //gui
      ..add('web/',null,staticHandler,exactMatch: false)
      //authenticate api
      ..add('api/',null,apiHandler,exactMatch: false,middleware:defaultAuthMiddleware);

  shelf_route.printRoutes(apiRouter);

  var handler = const shelf.Pipeline()
      //.addMiddleware(shelf_cors.createCorsHeadersMiddleware(corsHeaders:{'Access-Control-Allow-Origin': '*' /*, 'Access-Control-Allow-Headers': 'Origin, X-Requested-With, Content-Type, Accept, authorization','Access-Control-Allow-Credentials':'true'*/}))
      .addMiddleware(exceptionHandler())
      .addMiddleware(shelf.logRequests())
      .addHandler(apiRouter.handler);

  print("bind localhost on port ${config.currentLoadedConfig[config.MDT_SERVER_PORT]}");

  var server =  shelf_io.serve(handler, '0.0.0.0', config.currentLoadedConfig[config.MDT_SERVER_PORT]);
  server.then((server) {
      print('MDT started o@ port ${server.port}.');
      print('You can access server Web UI on http://localhost:${server.port}/web/');
      httpServer=server;
  });

  return new Future.value(server);
}

Future main() async{
  var server = await startServer();
}
