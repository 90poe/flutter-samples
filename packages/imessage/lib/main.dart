import 'package:flutter/cupertino.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    hide ChannelListView;

import 'package:imessage/channel_list_view.dart';

import 'package:imessage/channel_page_appbar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = StreamChatClient('b67pax5b2wdq', logLevel: Level.INFO); //
  await client.connectUser(
    User(
      id: 'cool-shadow-7',
      extraData: {
        'image':
            'https://getstream.io/random_png/?id=cool-shadow-7&amp;name=Cool+shadow',
      },
    ),
    'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoiY29vbC1zaGFkb3ctNyJ9.gkOlCRb1qgy4joHPaxFwPOdXcGvSPvp6QY0S4mpRkVo',
  );

  runApp(IMessage(client: client));
}

class IMessage extends StatelessWidget {
  final StreamChatClient client;
  IMessage({required this.client});
  @override
  Widget build(BuildContext context) {
    initializeDateFormatting('en_US', null);
    return CupertinoApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(brightness: Brightness.light),
      home: StreamChatCore(client: client, child: ChatLoader()),
    );
  }
}

class ChatLoader extends StatelessWidget {
  ChatLoader({
    Key? key,
  }) : super(key: key);

  final channelListController = ChannelListController();

  @override
  Widget build(BuildContext context) {
    final user = StreamChatCore.of(context).currentUser!;
    return CupertinoPageScaffold(
      child: ChannelsBloc(
        child: ChannelListCore(
          channelListController: channelListController,
          filter: Filter.and([
            Filter.in_('members', [user.id]),
            Filter.equal('type', 'messaging'),
          ]),
          sort: [SortOption('last_message_at')],
          pagination: PaginationParams(
            limit: 20,
          ),
          emptyBuilder: (BuildContext context) {
            return Center(
              child: Text('Looks like you are not in any channels'),
            );
          },
          loadingBuilder: (BuildContext context) {
            return Center(
              child: SizedBox(
                height: 100.0,
                width: 100.0,
                child: CupertinoActivityIndicator(),
              ),
            );
          },
          errorBuilder: (BuildContext context, dynamic error) {
            return Center(
              child: Text(
                  'Oh no, something went wrong. Please check your config.'),
            );
          },
          listBuilder: (
            BuildContext context,
            List<Channel> channels,
          ) =>
              LazyLoadScrollView(
            onEndOfPage: () async {
              return channelListController.paginateData!();
            },
            child: CustomScrollView(
              slivers: [
                CupertinoSliverRefreshControl(onRefresh: () async {
                  return channelListController.loadData!();
                }),
                ChannelPageAppBar(),
                SliverPadding(
                  sliver: ChannelListView(channels: channels),
                  padding: const EdgeInsets.only(top: 16),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
