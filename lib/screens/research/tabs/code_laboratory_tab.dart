import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/chat_state.dart';
import '../../../theme.dart';
import '../../../models.dart';
import 'agent_chat_tab.dart';

class CodeLaboratoryTab extends StatelessWidget {
  const CodeLaboratoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatState>();
    final terminalScrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (terminalScrollController.hasClients) {
        terminalScrollController.jumpTo(terminalScrollController.position.maxScrollExtent);
      }
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const Icon(Icons.science, color: OhadaTheme.accent),
              const SizedBox(width: 12),
              const Text('AUTONOMOUS DATA LABORATORY', 
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: OhadaTheme.accent)),
              const Spacer(),
              IconButton(
                icon: Icon(state.isTerminalExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                onPressed: () => state.toggleTerminal(),
              ),
              if (state.isLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: OhadaTheme.accent)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: AgentChatTab(agentIndex: 3, instruction: state.agentInstructions[3]!),
              ),
              if (state.isTerminalExpanded)
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.only(right: 12, bottom: 12, top: 0),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: const BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.terminal, size: 14, color: Colors.grey),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'PYTHON TERMINAL', 
                                  style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: terminalScrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: state.terminalLines.length,
                            itemBuilder: (context, index) {
                              return Text(state.terminalLines[index], style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12, color: Colors.greenAccent,
                              ));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
