import 'package:flutter/material.dart';

class ReusableSearchWidget<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) itemToString;
  final void Function(T) onItemSelected;
  final String hintText;
  final double resultsHeight; // height of the result list

  const ReusableSearchWidget({
    required this.items,
    required this.itemToString,
    required this.onItemSelected,
    this.hintText = "Search...",
    this.resultsHeight = 200, // default height
    Key? key,
  }) : super(key: key);

  @override
  _ReusableSearchWidgetState<T> createState() =>
      _ReusableSearchWidgetState<T>();
}

class _ReusableSearchWidgetState<T> extends State<ReusableSearchWidget<T>> {
  List<T> filteredItems = [];
  TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredItems = widget.items;
    controller.addListener(() {
      final query = controller.text.toLowerCase();
      setState(() {
        filteredItems = widget.items
            .where(
              (item) => widget.itemToString(item).toLowerCase().contains(query),
            )
            .toList();
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search box
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Results container
          Container(
            height: widget.resultsHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: filteredItems.isEmpty
                ? Center(
                    child: Text(
                      "No results found",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return ListTile(
                        title: Text(widget.itemToString(item)),
                        onTap: () => widget.onItemSelected(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
