import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/painting.dart';

import 'document.dart';

/// Stylesheet for styling content within a document.
///
/// A stylesheet is a series of priority-order rules that generate style
/// metadata, which is then applied to the layout and the blocks within the
/// layout.
class Stylesheet {
  const Stylesheet({
    this.documentPadding,
    required this.rules,
    required this.inlineTextStyler,
  });

  /// Padding applied around the interior edge of the document.
  ///
  /// A `null` value means that you have no opinion about the padding and
  /// you want to defer to other style preferences, as opposed to
  /// `EdgeInsets.zero`, which means that you affirmatively want zero padding.
  final EdgeInsets? documentPadding;

  /// Styles all in-line text in the document.
  final AttributionStyleAdjuster inlineTextStyler;

  /// Priority-order list of style rules.
  final List<StyleRule> rules;

  Stylesheet copyWith({
    EdgeInsets? documentPadding,
    AttributionStyleAdjuster? inlineTextStyler,
    List<StyleRule> addRulesBefore = const [],
    List<StyleRule>? rules,
    List<StyleRule> addRulesAfter = const [],
  }) {
    return Stylesheet(
      documentPadding: documentPadding ?? this.documentPadding,
      inlineTextStyler: inlineTextStyler ?? this.inlineTextStyler,
      rules: [
        ...addRulesBefore,
        ...(rules ?? this.rules),
        ...addRulesAfter,
      ],
    );
  }
}

/// Adjusts the given [existingStyle] based on the given [attributions].
typedef AttributionStyleAdjuster = TextStyle Function(Set<Attribution> attributions, TextStyle existingStyle);

/// A single style rule within a [Stylesheet].
///
/// A style rule combines a [selector], which identifies desired blocks within
/// a document, and a [styler], which generates style metadata for those blocks.
///
/// There is no explicit contract for the style metadata. Different blocks might
/// expect different styles. For example, a paragraph might understand text styles,
/// but an image wouldn't. The style system ignores any style metadata that a
/// given block doesn't understand.
class StyleRule {
  const StyleRule(this.selector, this.styler);

  /// Selector that identifies document blocks that this rule should apply to.
  final BlockSelector selector;

  /// Styles the blocks that this rule applies to.
  final Styler styler;
}

/// Generates style metadata for the given [DocumentNode] within the [Document].
typedef Styler = Map<String, dynamic> Function(Document, DocumentNode);

/// Selects blocks in a document that matches a given rule.
class BlockSelector {
  const BlockSelector(this._blockType)
      : _precedingBlockType = null,
        _followingBlockType = null,
        _indexMatcher = null;

  const BlockSelector.all()
      : _blockType = null,
        _precedingBlockType = null,
        _followingBlockType = null,
        _indexMatcher = null;

  const BlockSelector._({
    String? blockType,
    String? precedingBlockType,
    String? followingBlockType,
    _BlockMatcher? indexMatcher,
  })  : _blockType = blockType,
        _precedingBlockType = precedingBlockType,
        _followingBlockType = followingBlockType,
        _indexMatcher = indexMatcher;

  /// The desired type of block, or `null` to match any block.
  final String? _blockType;

  /// Type of block that appears immediately before the desired block.
  final String? _precedingBlockType;

  /// Returns a modified version of this selector that only selects blocks
  /// that appear immediately after the given [_blockType].
  BlockSelector after(String precedingBlockType) => BlockSelector._(
        blockType: _blockType,
        precedingBlockType: precedingBlockType,
        followingBlockType: _followingBlockType,
      );

  /// Type of block that appears immediately after the desired block.
  final String? _followingBlockType;

  /// Returns a modified version of this selector that only selects blocks
  /// that appear immediately before the given [_blockType].
  BlockSelector before(String followingBlockType) => BlockSelector._(
        blockType: _blockType,
        precedingBlockType: _precedingBlockType,
        followingBlockType: followingBlockType,
      );

  final _BlockMatcher? _indexMatcher;

  BlockSelector first() => BlockSelector._(
        blockType: _blockType,
        precedingBlockType: _precedingBlockType,
        followingBlockType: _followingBlockType,
        indexMatcher: const _FirstBlockMatcher(),
      );

  BlockSelector last() => BlockSelector._(
        blockType: _blockType,
        precedingBlockType: _precedingBlockType,
        followingBlockType: _followingBlockType,
        indexMatcher: const _LastBlockMatcher(),
      );

  BlockSelector atIndex(int index) => BlockSelector._(
        blockType: _blockType,
        precedingBlockType: _precedingBlockType,
        followingBlockType: _followingBlockType,
        indexMatcher: _IndexBlockMatcher(index),
      );

  /// Returns `true` if this selector matches the block for the given [node], or
  /// `false`, otherwise.
  bool matches(Document document, DocumentNode node) {
    if (_blockType != null && (node.getMetadataValue("blockType") as NamedAttribution?)?.name != _blockType) {
      return false;
    }

    if (_indexMatcher != null && !_indexMatcher!.matches(document, node)) {
      return false;
    }

    if (_precedingBlockType != null) {
      final nodeBefore = document.getNodeBefore(node);
      if (nodeBefore == null ||
          (nodeBefore.getMetadataValue("blockType") as NamedAttribution?)?.name != _precedingBlockType) {
        return false;
      }
    }

    if (_followingBlockType != null) {
      final nodeAfter = document.getNodeAfter(node);
      if (nodeAfter == null ||
          (nodeAfter.getMetadataValue("blockType") as NamedAttribution?)?.name != _followingBlockType) {
        return false;
      }
    }

    return true;
  }

  @override
  String toString() =>
      "${_precedingBlockType != null ? "$_precedingBlockType + " : ""}[$_blockType]${_followingBlockType != null ? " + $_followingBlockType" : ""}";
}

abstract class _BlockMatcher {
  bool matches(Document document, DocumentNode node);
}

class _FirstBlockMatcher implements _BlockMatcher {
  const _FirstBlockMatcher();

  @override
  bool matches(Document document, DocumentNode node) {
    return document.getNodeIndex(node) == 0;
  }
}

class _LastBlockMatcher implements _BlockMatcher {
  const _LastBlockMatcher();

  @override
  bool matches(Document document, DocumentNode node) {
    return document.getNodeIndex(node) == document.nodes.length - 1;
  }
}

class _IndexBlockMatcher implements _BlockMatcher {
  const _IndexBlockMatcher(this._index);

  final int _index;

  @override
  bool matches(Document document, DocumentNode node) {
    return document.getNodeIndex(node) == _index;
  }
}

/// Padding that accepts null padding values for desired sides, so that this
/// [CascadingPadding] can combine with other [CascadingPadding]s to produce
/// an overall padding configuration.
class CascadingPadding {
  /// Padding where all four sides have the given [padding].
  const CascadingPadding.all(double padding)
      : left = padding,
        right = padding,
        top = padding,
        bottom = padding;

  /// Padding where the left/right sides have [horizontal] padding, and
  /// top/bottom sides have [vertical] padding.
  const CascadingPadding.symmetric({
    double? horizontal,
    double? vertical,
  })  : left = horizontal,
        right = horizontal,
        top = vertical,
        bottom = vertical;

  /// Padding with the given [left], [right], [top], and [bottom] padding values.
  const CascadingPadding.only({
    this.left,
    this.right,
    this.top,
    this.bottom,
  });

  final double? left;
  final double? right;
  final double? top;
  final double? bottom;

  CascadingPadding applyOnTopOf(CascadingPadding other) => CascadingPadding.only(
        left: left ?? other.left,
        right: right ?? other.right,
        top: top ?? other.top,
        bottom: bottom ?? other.bottom,
      );

  EdgeInsets toEdgeInsets() => EdgeInsets.only(
        left: left ?? 0.0,
        right: right ?? 0.0,
        top: top ?? 0.0,
        bottom: bottom ?? 0.0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CascadingPadding &&
          runtimeType == other.runtimeType &&
          left == other.left &&
          right == other.right &&
          top == other.top &&
          bottom == other.bottom;

  @override
  int get hashCode => left.hashCode ^ right.hashCode ^ top.hashCode ^ bottom.hashCode;
}

/// Styles applied to the user's selection, e.g., caret, selected text.
class SelectionStyles {
  const SelectionStyles({
    required this.caretColor,
    required this.selectionColor,
    this.highlightEmptyTextBlocks = true,
  });

  /// The color of the caret.
  final Color caretColor;

  /// The color of selection rectangles.
  final Color selectionColor;

  /// Whether to show a small highlight at the beginning of an
  /// empty block of text, when the user selects multiple blocks.
  final bool highlightEmptyTextBlocks;
}
