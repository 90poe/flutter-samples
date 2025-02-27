import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:example/localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jiffy/jiffy.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'channel_file_display_screen.dart';
import 'channel_media_display_screen.dart';
import 'channel_page.dart';
import 'chat_info_screen.dart';
import 'pinned_messages_screen.dart';
import 'routes/routes.dart';

class GroupInfoScreen extends StatefulWidget {
  final MessageThemeData messageTheme;

  const GroupInfoScreen({
    Key? key,
    required this.messageTheme,
  }) : super(key: key);

  @override
  _GroupInfoScreenState createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  TextEditingController? _nameController;

  TextEditingController? _searchController;
  String _userNameQuery = '';

  Timer? _debounce;
  Function? modalSetStateCallback;

  final FocusNode _focusNode = FocusNode();

  bool listExpanded = false;

  ValueNotifier<bool?> mutedBool = ValueNotifier(false);

  void _userNameListener() {
    if (_searchController!.text == _userNameQuery) {
      return;
    }
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted && modalSetStateCallback != null) {
        modalSetStateCallback!(() {
          _userNameQuery = _searchController!.text;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    var channel = StreamChannel.of(context);
    _nameController = TextEditingController.fromValue(
      TextEditingValue(
          text: (channel.channel.extraData['name'] as String?) ?? ''),
    );
    _searchController = TextEditingController()..addListener(_userNameListener);

    _nameController!.addListener(() {
      setState(() {});
    });
    mutedBool = ValueNotifier(StreamChannel.of(context).channel.isMuted);
  }

  @override
  Widget build(BuildContext context) {
    var channel = StreamChannel.of(context);

    return StreamBuilder<List<Member>>(
        stream: channel.channel.state!.membersStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              color: StreamChatTheme.of(context).colorTheme.disabled,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          var userMember = snapshot.data!.firstWhereOrNull(
            (e) => e.user!.id == StreamChat.of(context).currentUser!.id,
          );
          var isOwner = userMember?.role == 'owner';

          return Scaffold(
            backgroundColor: StreamChatTheme.of(context).colorTheme.appBg,
            appBar: AppBar(
              brightness: Theme.of(context).brightness,
              elevation: 1.0,
              toolbarHeight: 56.0,
              backgroundColor: StreamChatTheme.of(context).colorTheme.barsBg,
              leading: StreamBackButton(),
              title: Column(
                children: [
                  StreamBuilder<ChannelState>(
                      stream: channel.channelStateStream,
                      builder: (context, state) {
                        if (!state.hasData) {
                          return Text(
                            AppLocalizations.of(context).loading,
                            style: TextStyle(
                              color: StreamChatTheme.of(context)
                                  .colorTheme
                                  .textHighEmphasis,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }

                        return Text(
                          _getChannelName(
                            2 * MediaQuery.of(context).size.width / 3,
                            members: snapshot.data,
                            extraData: state.data!.channel!.extraData,
                            maxFontSize: 16.0,
                          )!,
                          style: TextStyle(
                            color: StreamChatTheme.of(context)
                                .colorTheme
                                .textHighEmphasis,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }),
                  SizedBox(
                    height: 3.0,
                  ),
                  Text(
                    '${channel.channel.memberCount} ${AppLocalizations.of(context).members}, ${snapshot.data?.where((e) => e.user!.online).length ?? 0} ${AppLocalizations.of(context).online}',
                    style: TextStyle(
                      color: StreamChatTheme.of(context)
                          .colorTheme
                          .textHighEmphasis
                          .withOpacity(0.5),
                      fontSize: 12.0,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              actions: [
                if (!channel.channel.isDistinct && isOwner)
                  StreamNeumorphicButton(
                    child: InkWell(
                      onTap: () {
                        _buildAddUserModal(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: StreamSvgIcon.userAdd(
                            color: StreamChatTheme.of(context)
                                .colorTheme
                                .accentPrimary),
                      ),
                    ),
                  ),
              ],
            ),
            body: ListView(
              children: [
                _buildMembers(snapshot.data!),
                Container(
                  height: 8.0,
                  color: StreamChatTheme.of(context).colorTheme.disabled,
                ),
                if (isOwner) _buildNameTile(),
                _buildOptionListTiles(),
              ],
            ),
          );
        });
  }

  Widget _buildMembers(List<Member> members) {
    final groupMembers = members
      ..sort((prev, curr) {
        if (curr.role == 'owner') return 1;
        return 0;
      });

    int groupMembersLength;

    if (listExpanded) {
      groupMembersLength = groupMembers.length;
    } else {
      groupMembersLength = groupMembers.length > 6 ? 6 : groupMembers.length;
    }

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: groupMembersLength,
          itemBuilder: (context, index) {
            final member = groupMembers[index];
            return Material(
              child: InkWell(
                onTap: () {
                  final userMember = groupMembers.firstWhereOrNull(
                    (e) => e.user!.id == StreamChat.of(context).currentUser!.id,
                  );
                  _showUserInfoModal(member.user, userMember?.role == 'owner');
                },
                child: Container(
                  height: 65.0,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 12.0,
                            ),
                            child: UserAvatar(
                              user: member.user!,
                              constraints: BoxConstraints.tightFor(
                                height: 40.0,
                                width: 40.0,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  member.user!.name,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(
                                  height: 1.0,
                                ),
                                Text(
                                  _getLastSeen(member.user!),
                                  style: TextStyle(
                                      color: StreamChatTheme.of(context)
                                          .colorTheme
                                          .textHighEmphasis
                                          .withOpacity(0.5)),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              member.role == 'owner'
                                  ? AppLocalizations.of(context).owner
                                  : '',
                              style: TextStyle(
                                  color: StreamChatTheme.of(context)
                                      .colorTheme
                                      .textHighEmphasis
                                      .withOpacity(0.5)),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 1.0,
                        color: StreamChatTheme.of(context).colorTheme.disabled,
                      ),
                    ],
                  ),
                ),
              ),
              color: StreamChatTheme.of(context).colorTheme.appBg,
            );
          },
        ),
        if (groupMembersLength != groupMembers.length)
          InkWell(
            onTap: () {
              setState(() {
                listExpanded = true;
              });
            },
            child: Material(
              color: StreamChatTheme.of(context).colorTheme.appBg,
              child: Container(
                height: 65.0,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 21.0, vertical: 12.0),
                            child: StreamSvgIcon.down(
                              color: StreamChatTheme.of(context)
                                  .colorTheme
                                  .textLowEmphasis,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${members.length - groupMembersLength} ${AppLocalizations.of(context).more}',
                                  style: TextStyle(
                                      color: StreamChatTheme.of(context)
                                          .colorTheme
                                          .textLowEmphasis),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 1.0,
                      color: StreamChatTheme.of(context).colorTheme.disabled,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNameTile() {
    var channel = StreamChannel.of(context).channel;
    var channelName = (channel.extraData['name'] as String?) ?? '';

    return Material(
      color: StreamChatTheme.of(context).colorTheme.appBg,
      child: Container(
        height: 56.0,
        alignment: Alignment.center,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(7.0),
              child: Text(
                AppLocalizations.of(context).name.toUpperCase(),
                style: StreamChatTheme.of(context).textTheme.footnote.copyWith(
                    color: StreamChatTheme.of(context)
                        .colorTheme
                        .textHighEmphasis
                        .withOpacity(0.5)),
              ),
            ),
            SizedBox(
              width: 7.0,
            ),
            Expanded(
              child: TextField(
                focusNode: _focusNode,
                controller: _nameController,
                cursorColor:
                    StreamChatTheme.of(context).colorTheme.textHighEmphasis,
                decoration: InputDecoration.collapsed(
                    hintText: AppLocalizations.of(context).addAGroupName,
                    hintStyle: StreamChatTheme.of(context)
                        .textTheme
                        .bodyBold
                        .copyWith(
                            color: StreamChatTheme.of(context)
                                .colorTheme
                                .textHighEmphasis
                                .withOpacity(0.5))),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 0.82,
                ),
              ),
            ),
            if (channelName != _nameController!.text.trim())
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    child: StreamSvgIcon.closeSmall(),
                    onTap: () {
                      setState(() {
                        _nameController!.text = _getChannelName(
                          2 * MediaQuery.of(context).size.width / 3,
                          members: channel.state!.members,
                          extraData: channel.extraData,
                          maxFontSize: 16.0,
                        )!;
                        _focusNode.unfocus();
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, left: 8.0),
                    child: InkWell(
                      child: StreamSvgIcon.check(
                        color: StreamChatTheme.of(context)
                            .colorTheme
                            .accentPrimary,
                        size: 24.0,
                      ),
                      onTap: () {
                        StreamChannel.of(context).channel.update({
                          'name': _nameController!.text.trim(),
                        }).catchError((err) {
                          setState(() {
                            _nameController!.text = channelName;
                            _focusNode.unfocus();
                          });
                        });
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionListTiles() {
    var channel = StreamChannel.of(context);

    return Column(
      children: [
        // OptionListTile(
        //   title: 'Notifications',
        //   leading: StreamSvgIcon.Icon_notification(
        //     size: 24.0,
        //     color: StreamChatTheme.of(context).colorTheme.textHighEmphasis.withOpacity(0.5),
        //   ),
        //   trailing: CupertinoSwitch(
        //     value: true,
        //     onChanged: (val) {},
        //   ),
        //   onTap: () {},
        // ),
        StreamBuilder<bool>(
            stream: StreamChannel.of(context).channel.isMutedStream,
            builder: (context, snapshot) {
              mutedBool.value = snapshot.data;

              return OptionListTile(
                tileColor: StreamChatTheme.of(context).colorTheme.appBg,
                separatorColor: StreamChatTheme.of(context).colorTheme.disabled,
                title: AppLocalizations.of(context).muteGroup,
                titleTextStyle: StreamChatTheme.of(context).textTheme.body,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: StreamSvgIcon.mute(
                    size: 24.0,
                    color: StreamChatTheme.of(context)
                        .colorTheme
                        .textHighEmphasis
                        .withOpacity(0.5),
                  ),
                ),
                trailing: snapshot.data == null
                    ? CircularProgressIndicator()
                    : ValueListenableBuilder<bool?>(
                        valueListenable: mutedBool,
                        builder: (context, value, _) {
                          return CupertinoSwitch(
                            value: value!,
                            onChanged: (val) {
                              mutedBool.value = val;

                              if (snapshot.data!) {
                                channel.channel.unmute();
                              } else {
                                channel.channel.mute();
                              }
                            },
                          );
                        }),
                onTap: () {},
              );
            }),
        OptionListTile(
          title: AppLocalizations.of(context).pinnedMessages,
          tileColor: StreamChatTheme.of(context).colorTheme.appBg,
          titleTextStyle: StreamChatTheme.of(context).textTheme.body,
          leading: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: StreamSvgIcon.pin(
              size: 24.0,
              color: StreamChatTheme.of(context)
                  .colorTheme
                  .textHighEmphasis
                  .withOpacity(0.5),
            ),
          ),
          trailing: StreamSvgIcon.right(
            color: StreamChatTheme.of(context).colorTheme.textLowEmphasis,
          ),
          onTap: () {
            final channel = StreamChannel.of(context).channel;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StreamChannel(
                  channel: channel,
                  child: MessageSearchBloc(
                    child: PinnedMessagesScreen(
                      messageTheme: widget.messageTheme,
                      sortOptions: [
                        SortOption(
                          'created_at',
                          direction: SortOption.ASC,
                        ),
                      ],
                      paginationParams: PaginationParams(limit: 20),
                      onShowMessage: (m, c) async {
                        final client = StreamChat.of(context).client;
                        final message = m;
                        final channel = client.channel(
                          c.type,
                          id: c.id,
                        );
                        if (channel.state == null) {
                          await channel.watch();
                        }
                        Navigator.pushNamed(
                          context,
                          Routes.CHANNEL_PAGE,
                          arguments: ChannelPageArgs(
                            channel: channel,
                            initialMessage: message,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        OptionListTile(
          tileColor: StreamChatTheme.of(context).colorTheme.appBg,
          separatorColor: StreamChatTheme.of(context).colorTheme.disabled,
          title: AppLocalizations.of(context).photosAndVideos,
          titleTextStyle: StreamChatTheme.of(context).textTheme.body,
          leading: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: StreamSvgIcon.pictures(
              size: 32.0,
              color: StreamChatTheme.of(context)
                  .colorTheme
                  .textHighEmphasis
                  .withOpacity(0.5),
            ),
          ),
          trailing: StreamSvgIcon.right(
            color: StreamChatTheme.of(context).colorTheme.textLowEmphasis,
          ),
          onTap: () {
            var channel = StreamChannel.of(context).channel;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StreamChannel(
                  channel: channel,
                  child: MessageSearchBloc(
                    child: ChannelMediaDisplayScreen(
                      messageTheme: widget.messageTheme,
                      sortOptions: [
                        SortOption(
                          'created_at',
                          direction: SortOption.ASC,
                        ),
                      ],
                      paginationParams: PaginationParams(limit: 20),
                      onShowMessage: (m, c) async {
                        final client = StreamChat.of(context).client;
                        final message = m;
                        final channel = client.channel(
                          c.type,
                          id: c.id,
                        );
                        if (channel.state == null) {
                          await channel.watch();
                        }
                        await Navigator.pushNamed(
                          context,
                          Routes.CHANNEL_PAGE,
                          arguments: ChannelPageArgs(
                            channel: channel,
                            initialMessage: message,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        OptionListTile(
          tileColor: StreamChatTheme.of(context).colorTheme.appBg,
          separatorColor: StreamChatTheme.of(context).colorTheme.disabled,
          title: AppLocalizations.of(context).files,
          titleTextStyle: StreamChatTheme.of(context).textTheme.body,
          leading: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: StreamSvgIcon.files(
              size: 32.0,
              color: StreamChatTheme.of(context)
                  .colorTheme
                  .textHighEmphasis
                  .withOpacity(0.5),
            ),
          ),
          trailing: StreamSvgIcon.right(
            color: StreamChatTheme.of(context).colorTheme.textLowEmphasis,
          ),
          onTap: () {
            var channel = StreamChannel.of(context).channel;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StreamChannel(
                  channel: channel,
                  child: MessageSearchBloc(
                    child: ChannelFileDisplayScreen(
                      sortOptions: [
                        SortOption(
                          'created_at',
                          direction: SortOption.ASC,
                        ),
                      ],
                      paginationParams: PaginationParams(limit: 20),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (!channel.channel.isDistinct)
          OptionListTile(
            tileColor: StreamChatTheme.of(context).colorTheme.appBg,
            separatorColor: StreamChatTheme.of(context).colorTheme.disabled,
            title: AppLocalizations.of(context).leaveGroup,
            titleTextStyle: StreamChatTheme.of(context).textTheme.body,
            leading: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: StreamSvgIcon.userRemove(
                size: 24.0,
                color: StreamChatTheme.of(context)
                    .colorTheme
                    .textHighEmphasis
                    .withOpacity(0.5),
              ),
            ),
            trailing: Container(
              height: 24.0,
              width: 24.0,
            ),
            onTap: () async {
              final res = await showConfirmationDialog(
                context,
                title: AppLocalizations.of(context).leaveConversation,
                okText: AppLocalizations.of(context).leave.toUpperCase(),
                question:
                    AppLocalizations.of(context).leaveConversationAreYouSure,
                cancelText: AppLocalizations.of(context).cancel.toUpperCase(),
                icon: StreamSvgIcon.userRemove(
                  color: StreamChatTheme.of(context).colorTheme.accentError,
                ),
              );
              if (res == true) {
                final channel = StreamChannel.of(context).channel;
                await channel
                    .removeMembers([StreamChat.of(context).currentUser!.id]);
                Navigator.pop(context);
              }
            },
          ),
      ],
    );
  }

  void _buildAddUserModal(context) {
    var channel = StreamChannel.of(context).channel;

    showDialog(
      useRootNavigator: false,
      context: context,
      barrierColor: StreamChatTheme.of(context).colorTheme.overlay,
      builder: (context) {
        return StatefulBuilder(builder: (context, modalSetState) {
          modalSetStateCallback = modalSetState;
          return Padding(
            padding: EdgeInsets.only(top: 16.0, left: 8.0, right: 8.0),
            child: Material(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
              ),
              clipBehavior: Clip.antiAlias,
              child: Scaffold(
                body: UsersBloc(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildTextInputSection(modalSetState),
                      ),
                      Expanded(
                        child: UserListView(
                          selectedUsers: {},
                          onUserTap: (user, _) async {
                            _searchController!.clear();

                            await channel.addMembers([user.id]);
                            Navigator.pop(context);
                            setState(() {});
                          },
                          crossAxisCount: 4,
                          pagination: PaginationParams(
                            limit: 25,
                          ),
                          filter: Filter.and(
                            [
                              if (_searchController!.text.isNotEmpty)
                                Filter.autoComplete('name', _userNameQuery),
                              Filter.notIn('id', [
                                StreamChat.of(context).currentUser!.id,
                                ...channel.state!.members
                                    .map<String?>(((e) => e.userId))
                                    .whereType<String>(),
                              ]),
                            ],
                          ),
                          sort: [
                            SortOption(
                              'name',
                              direction: 1,
                            ),
                          ],
                          emptyBuilder: (_) {
                            return LayoutBuilder(
                              builder: (context, viewportConstraints) {
                                return SingleChildScrollView(
                                  physics: AlwaysScrollableScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: viewportConstraints.maxHeight,
                                    ),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: StreamSvgIcon.search(
                                              size: 96,
                                              color: StreamChatTheme.of(context)
                                                  .colorTheme
                                                  .textLowEmphasis,
                                            ),
                                          ),
                                          Text(AppLocalizations.of(context)
                                              .noUserMatchesTheseKeywords),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildTextInputSection(modalSetState) {
    final theme = StreamChatTheme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Container(
                height: 36,
                child: TextField(
                  controller: _searchController,
                  cursorColor: theme.colorTheme.textHighEmphasis,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).search,
                    hintStyle: theme.textTheme.body.copyWith(
                      color: theme.colorTheme.textLowEmphasis,
                    ),
                    prefixIconConstraints: BoxConstraints.tight(Size(40, 24)),
                    prefixIcon: StreamSvgIcon.search(
                      color: theme.colorTheme.textHighEmphasis,
                      size: 24,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24.0),
                      borderSide: BorderSide(
                        color: theme.colorTheme.borders,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.0),
                        borderSide: BorderSide(
                          color: theme.colorTheme.borders,
                        )),
                    contentPadding: const EdgeInsets.all(0),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.0),
            IconButton(
              icon: StreamSvgIcon.closeSmall(
                color: theme.colorTheme.textLowEmphasis,
              ),
              constraints: BoxConstraints.tightFor(
                height: 24,
                width: 24,
              ),
              padding: EdgeInsets.zero,
              splashRadius: 24,
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
      ],
    );
  }

  void _showUserInfoModal(User? user, bool isUserAdmin) {
    var channel = StreamChannel.of(context).channel;
    final color = StreamChatTheme.of(context).colorTheme.barsBg;

    showModalBottomSheet(
      useRootNavigator: false,
      context: context,
      clipBehavior: Clip.antiAlias,
      isScrollControlled: true,
      backgroundColor: color,
      builder: (context) {
        return SafeArea(
          child: StreamChannel(
            channel: channel,
            child: Material(
              color: color,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 24.0,
                  ),
                  Center(
                    child: Text(
                      user!.name,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 5.0,
                  ),
                  _buildConnectedTitleState(user)!,
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: UserAvatar(
                        user: user,
                        constraints: BoxConstraints.tightFor(
                          height: 64.0,
                          width: 64.0,
                        ),
                        borderRadius: BorderRadius.circular(32.0),
                      ),
                    ),
                  ),
                  if (StreamChat.of(context).currentUser!.id != user.id)
                    _buildModalListTile(
                      context,
                      StreamSvgIcon.user(
                        color: StreamChatTheme.of(context)
                            .colorTheme
                            .textLowEmphasis,
                        size: 24.0,
                      ),
                      AppLocalizations.of(context).viewInfo,
                      () async {
                        var client = StreamChat.of(context).client;

                        var c = client.channel('messaging', extraData: {
                          'members': [
                            user.id,
                            StreamChat.of(context).currentUser!.id,
                          ],
                        });

                        await c.watch();

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StreamChannel(
                              channel: c,
                              child: ChatInfoScreen(
                                messageTheme: widget.messageTheme,
                                user: user,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  if (StreamChat.of(context).currentUser!.id != user.id)
                    _buildModalListTile(
                      context,
                      StreamSvgIcon.message(
                        color: StreamChatTheme.of(context)
                            .colorTheme
                            .textLowEmphasis,
                        size: 24.0,
                      ),
                      AppLocalizations.of(context).message,
                      () async {
                        var client = StreamChat.of(context).client;

                        var c = client.channel('messaging', extraData: {
                          'members': [
                            user.id,
                            StreamChat.of(context).currentUser!.id,
                          ],
                        });

                        await c.watch();

                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StreamChannel(
                              channel: c,
                              child: ChannelPage(),
                            ),
                          ),
                        );
                      },
                    ),
                  // if (!channel.isDistinct &&
                  //     StreamChat.of(context).user!.id != user.id &&
                  //     isUserAdmin)
                  //   _buildModalListTile(
                  //       context,
                  //       StreamSvgIcon.iconUserSettings(
                  //         color: StreamChatTheme.of(context).colorTheme.textLowEmphasis,
                  //         size: 24.0,
                  //       ),
                  //       'Make Owner', () {
                  //     // TODO: Add make owner implementation (Remaining from backend)
                  //   }),
                  if (!channel.isDistinct &&
                      StreamChat.of(context).currentUser!.id != user.id &&
                      isUserAdmin)
                    _buildModalListTile(
                        context,
                        StreamSvgIcon.userRemove(
                          color: StreamChatTheme.of(context)
                              .colorTheme
                              .accentError,
                          size: 24.0,
                        ),
                        AppLocalizations.of(context).removeFromGroup, () async {
                      final res = await showConfirmationDialog(
                        context,
                        title: AppLocalizations.of(context).removeMember,
                        okText:
                            AppLocalizations.of(context).remove.toUpperCase(),
                        question:
                            AppLocalizations.of(context).removeMemberAreYouSure,
                        cancelText:
                            AppLocalizations.of(context).cancel.toUpperCase(),
                      );

                      if (res == true) {
                        await channel.removeMembers([user.id]);
                      }
                      Navigator.pop(context);
                    },
                        color:
                            StreamChatTheme.of(context).colorTheme.accentError),
                  _buildModalListTile(
                      context,
                      StreamSvgIcon.closeSmall(
                        color: StreamChatTheme.of(context)
                            .colorTheme
                            .textLowEmphasis,
                        size: 24.0,
                      ),
                      AppLocalizations.of(context).cancel, () {
                    Navigator.pop(context);
                  }),
                ],
              ),
            ),
          ),
        );
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
      ),
    );
  }

  Widget? _buildConnectedTitleState(User? user) {
    var alternativeWidget;

    final otherMember = user;

    if (otherMember != null) {
      if (otherMember.online) {
        alternativeWidget = Text(
          AppLocalizations.of(context).online,
          style: TextStyle(
              color: StreamChatTheme.of(context)
                  .colorTheme
                  .textHighEmphasis
                  .withOpacity(0.5)),
        );
      } else {
        alternativeWidget = Text(
          '${AppLocalizations.of(context).lastSeen} ${Jiffy(otherMember.lastActive).fromNow()}',
          style: TextStyle(
              color: StreamChatTheme.of(context)
                  .colorTheme
                  .textHighEmphasis
                  .withOpacity(0.5)),
        );
      }
    }

    return alternativeWidget;
  }

  Widget _buildModalListTile(
      BuildContext context, Widget leading, String title, VoidCallback onTap,
      {Color? color}) {
    color ??= StreamChatTheme.of(context).colorTheme.textHighEmphasis;

    return Material(
      color: StreamChatTheme.of(context).colorTheme.barsBg,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 1.0,
              color: StreamChatTheme.of(context).colorTheme.disabled,
            ),
            Container(
              height: 64.0,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: leading,
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _getChannelName(
    double width, {
    List<Member>? members,
    required Map extraData,
    double? maxFontSize,
  }) {
    String? title;
    var client = StreamChat.of(context);
    if (extraData['name'] == null) {
      final otherMembers =
          members!.where((member) => member.user!.id != client.currentUser!.id);
      if (otherMembers.isNotEmpty) {
        final maxWidth = width;
        final maxChars = maxWidth / maxFontSize!;
        var currentChars = 0;
        final currentMembers = <Member>[];
        otherMembers.forEach((element) {
          final newLength = currentChars + element.user!.name.length;
          if (newLength < maxChars) {
            currentChars = newLength;
            currentMembers.add(element);
          }
        });

        final exceedingMembers = otherMembers.length - currentMembers.length;
        title =
            '${currentMembers.map((e) => e.user!.name).join(', ')} ${exceedingMembers > 0 ? '+ $exceedingMembers' : ''}';
      } else {
        title = AppLocalizations.of(context).noTitle;
      }
    } else {
      title = extraData['name'];
    }
    return title;
  }

  String _getLastSeen(User user) {
    if (user.online) {
      return AppLocalizations.of(context).online;
    } else {
      return '${AppLocalizations.of(context).lastSeen} ${Jiffy(user.lastActive).fromNow()}';
    }
  }
}
