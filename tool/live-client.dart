import 'dart:io';
import 'dart:convert';
import 'package:raft_client/raft_client.dart';
Future<void> main() async {
  final fixture=jsonDecode(File('.local/test-user.json').readAsStringSync());
  final client=RaftClient(origin:fixture['origin'],sessionStore:MemorySessionStore());
  try {
    await client.login(fixture['email'],fixture['password']);
    final servers=await client.servers();assert(servers.isNotEmpty);client.selectServer(servers.first.id);
    final channels=await client.channels();final joined=channels.where((c)=>c.joined).toList();assert(joined.isNotEmpty);
    final general=joined.where((c)=>c.name=='general').firstOrNull??joined.first;
    final page=await client.messagePage(general.id);assert((page['messages'] as List).isNotEmpty);
    final unread=await client.get('/channels/unread',query:{'summary':1});
    final safe={'authenticated':client.user!=null,'servers':servers.length,'channels':channels.length,'joined':joined.length,'messageCount':(page['messages'] as List).length,'pageKeys':page.keys.toList(),'unreadShape':unread is Map?unread.map((k,v)=>MapEntry(k,v is Map ? (v.isEmpty?{}:v.values.first) : v)):null};
    for(final path in ['/channels/inbox','channels/saved','/tasks/server','/agents','/servers/${servers.first.id}/machines','/servers/${servers.first.id}/members']) {
      final value=await client.get(path.startsWith('/')?path:'/$path');
      safe[path.contains(servers.first.id)?path.replaceAll(servers.first.id,'fixture-server'):path]=value is List ? {'count':value.length,'firstKeys':value.isEmpty?[]:(value.first as Map).keys.toList()} : {'keys':(value as Map).keys.toList()};
    }
    print(jsonEncode(safe));await client.logout();
  }finally {await client.dispose();}
}
