import 'package:flutter/material.dart';

class LabelSection extends StatefulWidget {
  const LabelSection({
    Key? key,
    this.section = const <dynamic>[],
    required this.baseCDNUrl,
  }) : super(key: key);

  final List<dynamic>? section;
  final String baseCDNUrl;

  @override
  _LabelSectionState createState() => _LabelSectionState();
}

class _LabelSectionState extends State<LabelSection> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58.0,
      width: MediaQuery.of(context).size.width,
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: widget.section!.length,
        itemBuilder: (context, index) {
          return _buildLabelWidget(
            section: widget.section!,
            index: index,
          );
        },
      ),
    );
  }

  Widget _buildLabelWidget({
    required List<dynamic> section,
    required int index,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 10.0,
        horizontal: 12.0,
      ),
      width: MediaQuery.of(context).size.width,
      color: const Color(0xBFFFF0BE),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
            ),
            child: _buildLabelComponentIcon(
              iconUrl: section[index] != null
                  ? section[index].labelIcon.toString()
                  : '',
            ),
          ),
          const SizedBox(
            width: 5.0,
          ),
          _buildLabelComponentDescription(
            labelTitle: section[index] != null
                ? section[index].labelTitle.toString()
                : '',
            labelDescription: section[index] != null
                ? section[index].labelDescription.toString()
                : '',
          ),
        ],
      ),
    );
  }

  Widget _buildLabelComponentIcon({required String? iconUrl}) {
    return Image.network(
      '${widget.baseCDNUrl}/$iconUrl',
      width: 35.0,
      height: 35.0,
      fit: BoxFit.cover,
    );
  }

  Widget _buildLabelComponentDescription({
    required String labelTitle,
    required String labelDescription,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          child: Text(
            labelTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.w500,
              color: Color(0xFF393939),
            ),
          ),
        ),
        FittedBox(
          child: Text(
            labelDescription,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 10.0,
              fontWeight: FontWeight.w400,
              color: Color(0xFF393939),
            ),
          ),
        ),
      ],
    );
  }
}
