import 'package:flutter/material.dart';
import 'package:linkify/linkify.dart';
import 'package:sph_plan/shared/unicode.dart';
import 'package:styled_text/styled_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../client/logger.dart';

class FormatPattern {
  late final RegExp regExp;
  late final String? startTag;
  late final String? endTag;
  late final int group;
  late final Map<String, String> map;

  FormatPattern(
      {required this.regExp,
      this.startTag,
      this.endTag,
      this.group = 1,
      this.map = const {}});
}

class FormattedText extends StatelessWidget {
  final String text;
  const FormattedText({super.key, required this.text});

  /// Replaces all occurrences of map keys with their respective value
  String convertByMap(String string, Map<String, String> map) {
    var str = string;
    for (var entry in map.entries) {
      str = str.replaceAll(entry.key, entry.value);
    }
    return str;
  }

  /// Converts Lanis-style formatting into pseudo-HTML using rules defined as in<br />
  /// https://support.schulportal.hessen.de/knowledgebase.php?article=664<br />
  ///<br />
  /// Implemented:<br />
  /// ** => <​b>,<br />
  /// __ => <​u>,<br />
  /// -- => <​i>,<br />
  /// ` or ``` => <​code>,<br />
  /// ​- => \u2022 (•),<br />
  /// _ and _() => character substitution subscript,<br />
  /// ^ and ^() => character substitution superscript,<br />
  /// 12.01.23, 12.01.2023 => <​date>,<br />
  /// 12:03 => <​time><br />
  String convertLanisSyntax(String lanisStyledText) {
    final List<FormatPattern> formatPatterns = [
      FormatPattern(
          regExp: RegExp(r"\*\*(([^*]|\*(?!\*))+)\*\*"),
          startTag: "<b>",
          endTag: "</b>"),
      FormatPattern(
          regExp: RegExp(r"__(([^_]|_(?!_))+)__"),
          startTag: "<u>",
          endTag: "</u>"),
      FormatPattern(regExp: RegExp(r"_\((\d+)\)"), map: digitsSubscript),
      FormatPattern(
          regExp: RegExp(r"_(\d)(?:(?!\n)\s|(?=\n))"), map: digitsSubscript),
      FormatPattern(regExp: RegExp(r"\^\((\d+)\)"), map: digitsSuperscript),
      FormatPattern(
          regExp: RegExp(r"\^(\d)(?:(?!\n)\s|(?=\n))"), map: digitsSuperscript),
      FormatPattern(
          regExp: RegExp(r"~~(([^~]|~(?!~))+)~~"),
          startTag: "<i>",
          endTag: "</i>"),
      FormatPattern(
          regExp: RegExp(r"--(([^-]|-(?!-))+)--"),
          startTag: "<del>",
          endTag: "</del>"),
      FormatPattern(
          regExp: RegExp(r"`(?!``)(.*)(?<!``)`"),
          startTag: "<code>",
          endTag: "</code>"),
      FormatPattern(
          regExp: RegExp(r"```\n*((?:[^`]|`(?!``))*)\n*```"),
          startTag: "<code>",
          endTag: "</code>"),
      FormatPattern(
          regExp: RegExp(r"(\d{2}\.\d{1,2}\.(\d{4}|\d{2}\b))"),
          startTag: "<date>",
          endTag: "</date>"),
      FormatPattern(
          regExp:
              RegExp(r"(\d{2}:\d{2} Uhr)|(\d{2}:\d{2})", caseSensitive: false),
          startTag: "<time>",
          endTag: "</time>",
          group: 0),
      FormatPattern(
          regExp: RegExp(r"^[ \t]*-[ \t]*(.*)", multiLine: true),
          startTag: "\u2022 "),
    ];

    String formattedText = lanisStyledText;

    // Escape special characters so that StyledText doesn't use them for parsing.
    formattedText = formattedText.replaceAll("<", "&lt;");
    formattedText = formattedText.replaceAll(">", "&gt;");
    formattedText = formattedText.replaceAll("&", "&amp;");
    formattedText = formattedText.replaceAll('"', "&quot;");
    formattedText = formattedText.replaceAll("'", "&apos;");

    // Apply formatting
    for (final FormatPattern pattern in formatPatterns) {
      formattedText = formattedText.replaceAllMapped(
          pattern.regExp,
          (match) =>
              "${pattern.startTag ?? ""}${convertByMap(match.group(pattern.group)!, pattern.map)}${pattern.endTag ?? ""}");
    }

    // Surround emails and links with <a> tag
    final List<LinkifyElement> linkifiedElements = linkify(formattedText,
        options: const LinkifyOptions(humanize: true, removeWww: true),
        linkifiers: const [EmailLinkifier(), UrlLinkifier()]);

    String linkifiedText = "";

    for (LinkifyElement element in linkifiedElements) {
      if (element is UrlElement) {
        linkifiedText +=
            "<a href='${element.url}' type='url'>${element.text}</a>";
      } else if (element is EmailElement) {
        linkifiedText +=
            "<a href='${element.url}' type='email'>${element.text}</a>";
      } else {
        linkifiedText += element.text;
      }
    }

    return linkifiedText;
  }

  @override
  Widget build(BuildContext context) {
    return StyledText(
      text: convertLanisSyntax(text),
      style: Theme.of(context).textTheme.bodyMedium,
      tags: {
        "b": StyledTextTag(style: const TextStyle(fontWeight: FontWeight.bold)),
        "u": StyledTextTag(
            style: const TextStyle(decoration: TextDecoration.underline)),
        "i": StyledTextTag(style: const TextStyle(fontStyle: FontStyle.italic)),
        "del": StyledTextTag(
            style: const TextStyle(decoration: TextDecoration.lineThrough)),
        "code": StyledTextWidgetBuilderTag((context, _, textContent) => Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Container(
                padding: const EdgeInsets.only(
                    left: 8.0, right: 8.0, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.25),
                ),
                child: Text(
                  textContent!,
                  style: const TextStyle(
                    fontFamily: "Roboto Mono",
                  ),
                ),
              ),
            )),
        "date": StyledTextWidgetBuilderTag((context, _, textContent) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(Icons.calendar_today,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                ),
                Flexible(
                  child: Text(
                    textContent!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold),
                  ),
                )
              ],
            )),
        "time": StyledTextWidgetBuilderTag((context, _, textContent) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(Icons.access_time_filled,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                ),
                Flexible(
                  child: Text(
                    textContent!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold),
                  ),
                )
              ],
            )),
        "a": StyledTextWidgetBuilderTag((context, attributes, textContent) {
          late final Icon icon;

          if (attributes["type"] == "url") {
            icon =
                Icon(Icons.link, color: Theme.of(context).colorScheme.primary);
          } else {
            icon = Icon(Icons.email_rounded,
                color: Theme.of(context).colorScheme.primary);
          }

          return Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: InkWell(
              onTap: () async {
                if (!await launchUrl(Uri.parse(attributes["href"]!))) {
                  logger.w('${attributes["href"]} konnte nicht geöffnet werden.');
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                  padding: const EdgeInsets.only(
                      left: 7, right: 8, top: 2, bottom: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: icon,
                      ),
                      Flexible(
                        child: Text(
                          textContent!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  )),
            ),
          );
        }),
      },
    );
  }
}
