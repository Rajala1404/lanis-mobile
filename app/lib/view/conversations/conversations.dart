import 'package:flutter/material.dart';
import 'package:sph_plan/view/conversations/detailed_conversation.dart';

import '../../client/client.dart';
import '../../client/fetcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../shared/widgets/error_view.dart';

class ConversationsAnsicht extends StatefulWidget {
  const ConversationsAnsicht({super.key});

  @override
  State<StatefulWidget> createState() => _ConversationsAnsichtState();
}

class _ConversationsAnsichtState extends State<ConversationsAnsicht>
    with TickerProviderStateMixin {
  final InvisibleConversationsFetcher invisibleConversationsFetcher =
      client.fetchers.invisibleConversationsFetcher;
  final VisibleConversationsFetcher visibleConversationsFetcher =
      client.fetchers.visibleConversationsFetcher;

  static const double padding = 12.0;

  final GlobalKey<RefreshIndicatorState> _refreshVisibleKey =
      GlobalKey<RefreshIndicatorState>();
  final GlobalKey<RefreshIndicatorState> _refreshInvisibleKey =
      GlobalKey<RefreshIndicatorState>();

  dynamic visibleConversations;
  dynamic invisibleConversations;

  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);

    visibleConversationsFetcher.fetchData();
    invisibleConversationsFetcher.fetchData();

    super.initState();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void showSnackbar(String text, {seconds = 1, milliseconds = 0}) {
    if (mounted) {
      // Hide the current SnackBar if one is already visible.
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          duration: Duration(seconds: seconds, milliseconds: milliseconds),
        ),
      );
    }
  }

  Widget infoCard(context) => ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              flex: 3,
              child: Text(
                AppLocalizations.of(context)!.noFurtherEntries,
                style: const TextStyle(fontSize: 21),
              ),
            ),
          ],
        ),
      );

  Widget infoCardInvisibility(context) => ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              flex: 3,
              child: Text(
                AppLocalizations.of(context)!.note,
                style: const TextStyle(fontSize: 21),
              ),
            ),
          ],
        ),
        subtitle: Text(
          AppLocalizations.of(context)!.notificationsNote,
          style: const TextStyle(fontSize: 17),
        ),
      );

  Widget getConversationWidget(Map<String, dynamic> conversation) {
    return ListTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 3,
            child: Text(
              conversation["Betreff"] ?? "",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 21),
            ),
          ),
          Flexible(
            child: Text(
              conversation["kuerzel"] ?? "",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                conversation["Datum"] ?? "",
              )
            ],
          ),
        ],
      ),
      leading: conversation["unread"] != null && conversation["unread"] == 1
          ? const Icon(Icons.notification_important)
          : null,
    );
  }

  Widget conversationsView(
      BuildContext context, conversations, Fetcher fetcher, GlobalKey key) {
    return RefreshIndicator(
      key: key,
      onRefresh: () async {
        fetcher.fetchData(forceRefresh: true);
      },
      child: ListView.builder(
        itemCount: conversations.length + 1,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              left: padding,
              right: padding,
              bottom: index == conversations.length ? 14 : 8,
              top: index == 0 ? padding : 0,
            ),
            child: Card(
              child: InkWell(
                  onTap: () {
                    if (index == conversations.length) {
                      showSnackbar("(:");
                    } else {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => DetailedConversationAnsicht(
                                    uniqueID: conversations[index]
                                        ["Uniquid"], // nice typo Lanis
                                    title: conversations[index]["Betreff"],
                                  )));
                    }
                  },
                  customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: index == conversations.length
                      ? _tabController.index == 0
                          ? infoCard(context)
                          : infoCardInvisibility(context)
                      : getConversationWidget(conversations[index])),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TabBar(
        controller: _tabController,
        tabs: [
          Tab(
            text: AppLocalizations.of(context)!.visible,
            icon: const Icon(Icons.visibility),
          ),
          Tab(
            text: AppLocalizations.of(context)!.invisible,
            icon: const Icon(Icons.visibility_off),
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StreamBuilder(
              stream: visibleConversationsFetcher.stream,
              builder: (context, snapshot) {
                if (snapshot.data?.status == FetcherStatus.error) {
                  return ErrorView(
                      error: snapshot.data!.error!,
                      name: AppLocalizations.of(context)!.messages,
                      fetcher: visibleConversationsFetcher);
                } else if (snapshot.data?.status == FetcherStatus.fetching ||
                    snapshot.data == null) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  return conversationsView(context, snapshot.data?.content,
                      visibleConversationsFetcher, _refreshVisibleKey);
                }
              }),
          StreamBuilder(
              stream: invisibleConversationsFetcher.stream,
              builder: (context, snapshot) {
                if (snapshot.data?.status == FetcherStatus.error) {
                  return ErrorView.fromCode(
                      data: snapshot.data?.content,
                      name: AppLocalizations.of(context)!.messages,
                      fetcher: invisibleConversationsFetcher);
                } else if (snapshot.data?.status == FetcherStatus.fetching ||
                    snapshot.data == null) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  return conversationsView(context, snapshot.data?.content,
                      invisibleConversationsFetcher, _refreshInvisibleKey);
                }
              })
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _refreshVisibleKey.currentState?.show();
          _refreshInvisibleKey.currentState?.show();
        },
        heroTag: "RefreshConversations",
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
