enum FileCategory { literature, results, data }

class ResearchFile {
  final String name;
  final String content;
  final String type;
  final int charCount;
  String summary;
  FileCategory category;

  // Structured citation metadata — populated by the extraction pre-step
  String extractedAuthors;
  String extractedYear;
  String extractedTitle;
  String extractedDoi;
  String extractedJournal;

  ResearchFile({
    required this.name,
    required this.content,
    required this.type,
    required this.charCount,
    this.summary = "",
    this.category = FileCategory.literature,
    this.extractedAuthors = "",
    this.extractedYear = "",
    this.extractedTitle = "",
    this.extractedDoi = "",
    this.extractedJournal = "",
  });

  /// Whether structured metadata has been extracted for this file.
  bool get hasExtractedMetadata => extractedAuthors.isNotEmpty && extractedYear.isNotEmpty && extractedTitle.isNotEmpty;

  /// Build a short APA-style in-text key like "(Masoumi et al., 2021)"
  String get citationKey {
    if (!hasExtractedMetadata) return '(Unknown, n.d.)';
    final firstAuthor = extractedAuthors.split(',').first.split(' ').last.trim();
    final etAl = extractedAuthors.contains(',') ? ' et al.' : '';
    return '($firstAuthor$etAl, $extractedYear)';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'content': content,
    'type': type,
    'charCount': charCount,
    'summary': summary,
    'category': category.name,
    'extractedAuthors': extractedAuthors,
    'extractedYear': extractedYear,
    'extractedTitle': extractedTitle,
    'extractedDoi': extractedDoi,
    'extractedJournal': extractedJournal,
  };

  factory ResearchFile.fromJson(Map<String, dynamic> json) => ResearchFile(
    name: json['name'] as String,
    content: json['content'] as String,
    type: json['type'] as String,
    charCount: json['charCount'] as int,
    summary: json['summary'] as String? ?? "",
    category: FileCategory.values.firstWhere((e) => e.name == (json['category'] ?? 'literature'), orElse: () => FileCategory.literature),
    extractedAuthors: json['extractedAuthors'] as String? ?? "",
    extractedYear: json['extractedYear'] as String? ?? "",
    extractedTitle: json['extractedTitle'] as String? ?? "",
    extractedDoi: json['extractedDoi'] as String? ?? "",
    extractedJournal: json['extractedJournal'] as String? ?? "",
  );
}

class ChatMessage {
  final String id;
  final String role;
  final String content;
  final List<String>? images;
  final DateTime timestamp;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    this.images,
    DateTime? timestamp,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'images': images,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Serialization for Ollama API — only includes fields the API understands.
  Map<String, dynamic> toOllamaJson() {
    final json = <String, dynamic>{
      'role': role,
      'content': content,
    };
    if (images != null && images!.isNotEmpty) {
      json['images'] = images;
    }
    return json;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String?,
      role: json['role'] as String,
      content: json['content'] as String,
      images: (json['images'] as List?)?.map((e) => e as String).toList(),
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : null,
    );
  }
}

class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  TokenUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    int? totalTokens,
  }) : totalTokens = totalTokens ?? (promptTokens + completionTokens);

  /// Heuristically estimate tokens from string length (approx 4 chars per token)
  static TokenUsage fromTextEstimation(String prompt, String response) {
    final pt = (prompt.length / 4).ceil();
    final ct = (response.length / 4).ceil();
    return TokenUsage(promptTokens: pt, completionTokens: ct);
  }

  Map<String, dynamic> toJson() => {
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'totalTokens': totalTokens,
  };
}

class AiResponse {
  final ChatMessage message;
  final TokenUsage usage;

  AiResponse({required this.message, required this.usage});
}

class ChatSession {
  final String id;
  String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  String? contextText;  // Extracted text from PDF, DOCX, etc.
  String? contextName; // Original file name
  String? contextType; // 'pdf', 'docx', etc.
  String? contextSummary; // Cached summary of the context

  ChatSession({
    String? id,
    required this.title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    this.contextText,
    this.contextName,
    this.contextType,
    this.contextSummary,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now();

  int get contextCharCount => contextText?.length ?? 0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'contextText': contextText,
      'contextName': contextName,
      'contextType': contextType,
      'contextSummary': contextSummary,
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String?,
      title: json['title'] as String,
      messages: (json['messages'] as List?)
          ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      contextText: json['contextText'] as String?,
      contextName: json['contextName'] as String?,
      contextType: json['contextType'] as String?,
    );
  }
}

class ManuscriptSection {
  String id;
  String title;
  String content;
  int order;
  String customPrompt;
  List<ChatMessage> chatHistory;

  ManuscriptSection({
    String? id,
    required this.title,
    this.content = "",
    required this.order,
    this.customPrompt = "",
    List<ChatMessage>? chatHistory,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString() + title.hashCode.toString(),
       chatHistory = chatHistory ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'order': order,
    'customPrompt': customPrompt,
    'chatHistory': chatHistory.map((m) => m.toJson()).toList(),
  };

  factory ManuscriptSection.fromJson(Map<String, dynamic> json) => ManuscriptSection(
    id: json['id'] as String?,
    title: json['title'] as String,
    content: json['content'] as String? ?? "",
    order: json['order'] as int? ?? 0,
    customPrompt: json['customPrompt'] as String? ?? "",
    chatHistory: (json['chatHistory'] as List?)?.map((m) => ChatMessage.fromJson(m)).toList() ?? [],
  );
}

class ResearchProject {
  final String id;
  String title;
  DateTime createdAt;
  DateTime lastModified;
  
  // Persistence for each stage
  String litReview = "";
  String methodology = "";
  String analysis = "";
  String finalManuscript = ""; // Legacy/Reconstructed
  String projectType = "Academic Manuscript";
  List<ManuscriptSection> sections = [];
  Map<String, String> manuscriptSections = {}; // Legacy
  String reviewerFeedback = ""; // Feedback from the reviewer agent
  String lastCompletedStage = ""; // e.g. "LITERATURE"
  
  // File Repository
  List<ResearchFile> files = [];
  
  // Agent Chats (1-5)
  Map<int, List<ChatMessage>> agentChats = {
    1: [], 2: [], 3: [], 4: [], 5: []
  };

  // Settings
  String citationStyle = "APA";
  String? dataAnalysisModel; // Stage-specific override
  bool isAutonomousProactive = true;
  bool isDraftRefinementMode = false;
  String extraInstructions = "";
  String initialDraft = "";
  String reviewerInstructions = ""; 
  int totalTokensUsed = 0;

  ResearchProject({
    String? id,
    required this.title,
    this.projectType = "Academic Manuscript",
    DateTime? createdAt,
    DateTime? lastModified,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now(),
       lastModified = lastModified ?? DateTime.now() {
    // Initialize default sections based on projectType if empty
    if (sections.isEmpty) {
      _initializeSectionsForType();
    }
  }

  void _initializeSectionsForType() {
    final List<String> defaultTitles;
    final Map<String, String> defaultInstructions;

    switch (projectType) {
      case "Public Policy Draft":
        defaultTitles = [
          "Title", "Executive Summary", "Problem Statement", "Background & Context",
          "Policy Options", "Cost-Benefit Analysis", "Recommendations",
          "Implementation Plan", "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Title": "Generate a professional, policy-oriented title reflecting the socioeconomic, geopolitical, or administrative scope of the policy audit. Maximum 15 words.",
          "Executive Summary": "Provide a concise executive summary for policymakers and public administrators. Summarize the policy problem, the core analytical findings, the proposed reform options, and a clear strategic recommendation. Keep it under 300 words.",
          "Problem Statement": "Formulate a highly detailed, evidence-based statement of the public policy issue or challenge. Ground the arguments in quantitative data and academic literature, with robust in-text citations (author, year).",
          "Background & Context": "Synthesize the historical, institutional, and political context of this policy area. Contrast past approaches and legislative audits by synthesizing the provided literature, citing all sources accurately.",
          "Policy Options": "Develop 2-3 distinct, viable policy alternatives or options to address the defined challenge. Outline the institutional design, operational mechanism, and political feasibility of each alternative.",
          "Cost-Benefit Analysis": "Analyze the fiscal, economic, social, and environmental costs and benefits of each policy option. Present quantitative estimates where possible, citing evidence from source materials.",
          "Recommendations": "State a definitive, fully justified policy recommendation. Explain why this option is superior in terms of feasibility, cost-effectiveness, and equity.",
          "Implementation Plan": "Design a step-by-step roadmap for executing the recommended policy option. Detail lead agencies, timelines, resource allocation, and monitoring/evaluation metrics.",
          "References": "Provide a list of all legislative, governmental, and academic sources cited in the policy draft, formatted accurately with full bibliographic entries.",
        };
        break;

      case "NGO Project Report":
        defaultTitles = [
          "Project Title", "Executive Summary", "Needs Assessment", "Project Goals & Objectives",
          "Target Beneficiaries", "Methodology & Activities", "Monitoring & Evaluation",
          "Budget & Resource Allocation", "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Project Title": "Provide a compelling, objective title describing the development intervention, targeted community, and geographic scope. Maximum 15 words.",
          "Executive Summary": "Draft a high-impact executive summary summarizing the community need, project activities, key achievements, monitoring indicators, and budget utilization. Keep it under 250 words.",
          "Needs Assessment": "Elucidate the local community or humanitarian challenge this project addresses. Support the analysis with local survey findings, economic metrics, and external NGO/academic reports, citing all sources properly.",
          "Project Goals & Objectives": "List the specific, measurable, achievable, relevant, and time-bound (SMART) objectives of the intervention.",
          "Target Beneficiaries": "Define the demographic, geographic, and socioeconomic profiles of the direct and indirect beneficiaries, supported by data.",
          "Methodology & Activities": "Describe the practical steps, social mobilization strategies, educational campaigns, or infrastructure projects executed. Detail the operational workflow.",
          "Monitoring & Evaluation": "Explain the monitoring framework, evaluation methodologies, and key performance indicators (KPIs) used to measure project impact.",
          "Budget & Resource Allocation": "Provide a clear breakdown of resources, funding utilization, and logistical spending, citing financial reports where available.",
          "References": "Compile all source materials, organizational reports, and external datasets referenced in this report.",
        };
        break;

      case "Corporate Strategy Document":
        defaultTitles = [
          "Title", "Executive Summary", "Market Analysis (SWOT)", "Business Model",
          "Strategic Objectives", "Implementation Roadmap", "Risk Assessment",
          "Financial Forecasts", "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Title": "Generate a premium, strategic corporate title indicating the product, organizational unit, or market expansion focus. Maximum 15 words.",
          "Executive Summary": "Draft a compelling executive summary for executives and investors. Highlight the market opportunity, SWOT findings, core business model, key milestones, and financial forecast. Maximum 250 words.",
          "Market Analysis (SWOT)": "Present a granular analysis of market trends, industry growth, competitive landscaping, and a thorough SWOT (Strengths, Weaknesses, Opportunities, Threats) framework. Ground arguments in industry and academic research, citing sources.",
          "Business Model": "Detail the value proposition, customer segments, channel strategies, key partnerships, and revenue streams.",
          "Strategic Objectives": "Define the mid-term and long-term strategic objectives of the firm, focusing on market share, operational efficiency, or product innovation.",
          "Implementation Roadmap": "Detail a structured timeline, departmental milestones (R&D, marketing, sales, ops), and concrete action plans.",
          "Risk Assessment": "Analyze financial, technical, legal, and reputational risks, including mitigation strategies.",
          "Financial Forecasts": "Present realistic, quantitative projections (revenue, expenses, break-even analysis) for 3-5 years, supported by data analysis findings.",
          "References": "Provide clear bibliographic entries for all industry databases, academic reports, and corporate records cited.",
        };
        break;

      case "Technical Whitepaper":
        defaultTitles = [
          "Document Title", "Abstract", "Problem Definition", "System Architecture",
          "Technical Protocol", "Security & Cryptography", "Performance Benchmarks",
          "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Document Title": "Generate an authoritative, specialized title reflecting the technical protocol, algorithm, or architecture being proposed. Maximum 15 words.",
          "Abstract": "Summarize the technical contribution, the solved problem, standard parameters, and performance improvements in under 200 words.",
          "Problem Definition": "Formulate a rigorous mathematical or structural definition of the technical inefficiency, vulnerability, or scaling issue solved by this system.",
          "System Architecture": "Explain the structural design of the platform or protocol, detailing components, network layers, and system interfaces. Cite technical papers.",
          "Technical Protocol": "Detail the algorithm, state machine rules, consensus rules, or processing loops. Include equations or algorithmic pseudocode.",
          "Security & Cryptography": "Analyze the threat vectors, security guarantees, cryptographic primitives, and encryption schemes used.",
          "Performance Benchmarks": "Present objective latency, throughput, complexity, or resource usage data generated by simulated runs.",
          "References": "List the foundational academic papers, internet RFCs, and engineering specifications referenced.",
        };
        break;

      case "Market Research Analysis":
        defaultTitles = [
          "Title", "Executive Summary", "Industry Context", "Target Audience",
          "SWOT & Competitor Landscape", "Survey Findings", "Market Forecasting",
          "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Title": "Generate a commercial, insight-focused research title specifying the market segment and timeframe. Maximum 15 words.",
          "Executive Summary": "Summarize market size, Compound Annual Growth Rate (CAGR), primary consumer drivers, competitor strategies, and target opportunities.",
          "Industry Context": "Present macroeconomic and microeconomic trends shaping this industry, citing institutional databases and academic journals.",
          "Target Audience": "Segment customer demographics, behavioral archetypes, and purchasing intents using local survey findings.",
          "SWOT & Competitor Landscape": "Detail key market players, market shares, SWOT vectors, and entry barriers.",
          "Survey Findings": "Analyze survey datasets and qualitative metrics. Highlight correlation patterns and customer satisfaction indices.",
          "Market Forecasting": "Predict market trajectories, demand fluctuations, and investment paybacks using computational models and trends.",
          "References": "List all commercial databases, industry briefs, and economic papers cited.",
        };
        break;

      case "Grant Proposal Application":
        defaultTitles = [
          "Project Title", "Project Summary", "Institutional Background", "Problem Statement",
          "Goals & Objectives", "Work Plan", "Budget Justification",
          "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Project Title": "Generate a concise, funder-friendly project title emphasizing social, scientific, or developmental impact. Maximum 15 words.",
          "Project Summary": "Draft a compelling overview of the research/project goals, target community, expected milestones, and overall funding requested.",
          "Institutional Background": "Describe the executing institution's R&D capabilities, past successful grants, infrastructure, and team competencies.",
          "Problem Statement": "Establish the critical gap, societal pain point, or scientific mystery this proposal addresses, backed by rich literature citations.",
          "Goals & Objectives": "State clear, qualitative and quantitative goals and specific measurable milestones.",
          "Work Plan": "Detail the chronological execution steps, work packages, task allocations, and deliverables.",
          "Budget Justification": "Breakdown personnel, equipment, travel, and indirect costs, with detailed mathematical justifications.",
          "References": "Provide complete academic and regulatory citations supporting the research rationale.",
        };
        break;

      case "Feasibility Study":
        defaultTitles = [
          "Project Title", "Executive Summary", "Operational Feasibility", "Technical Architecture",
          "Financial Viability", "Risk Assessment", "Recommendations",
          "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Project Title": "Generate an objective project feasibility title. Maximum 15 words.",
          "Executive Summary": "Summarize the core proposal, operational/technical feasibility results, net present value (NPV), and strategic go/no-go recommendations.",
          "Operational Feasibility": "Evaluate staffing requirements, organizational alignment, process change impacts, and training needs.",
          "Technical Architecture": "Audit the software, hardware, or structural architectures required. Identify technical bottlenecks and integration risks.",
          "Financial Viability": "Formulate a detailed cost-benefit analysis, detailing internal rate of return (IRR), payback period, and budget sensitivities.",
          "Risk Assessment": "Categorize operational, technological, financial, and environmental risks with concrete mitigation protocols.",
          "Recommendations": "State a definitive and rigorous go/no-go business decision with strategic operational directions.",
          "References": "List all financial, industrial, and technology standards documents cited.",
        };
        break;

      case "Environmental Impact Assessment (EIA)":
        defaultTitles = [
          "Assessment Title", "Executive Summary", "Environmental Baseline", "Potential Impact Vectors",
          "Mitigation Framework", "Regulatory Compliance", "Environmental Monitoring",
          "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Assessment Title": "Provide an official, project-specific environmental assessment title specifying the site location. Maximum 15 words.",
          "Executive Summary": "Summarize baseline ecology, key impact vectors, mitigation steps, regulatory compliance status, and final sustainability score.",
          "Environmental Baseline": "Document local soil, water, air quality, flora, fauna, and socioeconomic baselines before construction or project start.",
          "Potential Impact Vectors": "Analyze potential pollution, ecosystem disruption, waste generation, and greenhouse gas footprints. Ground the analysis in site surveys.",
          "Mitigation Framework": "Design rigorous plans to prevent, minimize, or offset environmental degradation, including carbon offset projects.",
          "Regulatory Compliance": "Detail the statutory alignment with national, regional, and municipal environmental laws.",
          "Environmental Monitoring": "Formulate a concrete tracking protocol, including sensor deployments, inspection schedules, and emergency triggers.",
          "References": "Provide formatted references to ecological literature, municipal data, and environmental laws.",
        };
        break;

      case "Product Requirements Document (PRD)":
        defaultTitles = [
          "Product Title", "Goal & Vision", "User Personas", "User Stories",
          "Functional Requirements", "Non-Functional Requirements", "Release Criteria",
          "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Product Title": "Generate a precise product name and release version. Maximum 10 words.",
          "Goal & Vision": "Define the strategic business goal, product vision, customer problem solved, and key product success metrics (KPIs).",
          "User Personas": "Detail 2-3 target user personas, describing demographics, workflows, challenges, and core motivations.",
          "User Stories": "Draft high-fidelity user stories using the 'As a... I want to... So that...' Agile format with strict acceptance criteria.",
          "Functional Requirements": "List feature requirements, user flows, state modifications, and interaction designs in granular detail.",
          "Non-Functional Requirements": "Specify latency bounds, scalability metrics, browser/device support, and security compliance parameters.",
          "Release Criteria": "Define absolute QA test pass thresholds, user acceptance testing (UAT) checklists, and crash-rate boundaries for shipping.",
          "References": "List competitive products, user interviews, API documentation, or tech architectures reviewed.",
        };
        break;

      case "Clinical Trial Protocol":
        defaultTitles = [
          "Trial Title", "Clinical Synopsis", "Introduction & Rationale", "Trial Design",
          "Patient Eligibility", "Treatment Protocol", "Adverse Event Management",
          "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Trial Title": "Generate a scientific, official clinical trial protocol title specifying phases, compounds, and target indications. Maximum 15 words.",
          "Clinical Synopsis": "Provide a high-level summary of the phases, clinical endpoints (primary/secondary), patient cohorts, and treatment schedules.",
          "Introduction & Rationale": "Synthesize preclinical data, animal study models, and past human clinical literature to justify this trial. Cite all medical papers.",
          "Trial Design": "Formulate a double-blind, randomized, placebo-controlled, or cross-over study plan, detailing statistical power equations.",
          "Patient Eligibility": "Draft highly specific, bulleted lists of inclusion and exclusion criteria based on hematological, physiological, and age limits.",
          "Treatment Protocol": "Detail compound dosages, delivery routes, frequency, cycles, and drug storage parameters.",
          "Adverse Event Management": "Define the scoring metrics for toxicities, reporting requirements, dose reduction steps, and stopping rules.",
          "References": "List all medical journals, laboratory documentation, and ethical codes cited.",
        };
        break;

      case "Legal Opinion Brief":
        defaultTitles = [
          "Case Brief", "Summary of Facts", "Questions Presented", "Brief Answer",
          "Legal Discussion", "Precedent Case Audit", "Statutory Interpretation",
          "Recommendations", "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Case Brief": "Generate a concise formal header specifying the parties, case number, jurisdiction, and legal counsel names.",
          "Summary of Facts": "Provide an objective, chronologically sequenced account of the material events and disputes leading to this litigation.",
          "Questions Presented": "Formulate the exact legal questions or issues that the court or client needs answered.",
          "Brief Answer": "Provide a direct, one-sentence answer ('Yes', 'No', or conditional) to each Question Presented, followed by a brief 2-sentence rationale.",
          "Legal Discussion": "Apply the statutory frameworks and constitutional rules to the material facts, citing precedent cases.",
          "Precedent Case Audit": "Analyze relevant appellate or supreme court case law, comparing and contrasting their holdings with the current dispute.",
          "Statutory Interpretation": "Examine relevant statutes, legislative history, and plain-meaning statutory canons.",
          "Recommendations": "Formulate a strategic legal advisory, suggesting settlement steps, trial strategies, or governance adjustments.",
          "References": "Provide complete, standardized citation lists for all cases, statutes, and legal treatises referenced.",
        };
        break;

      case "Investment Memorandum":
        defaultTitles = [
          "Investment Memo Title", "Executive Summary", "Company Overview", "Market Opportunity",
          "Financial Performance", "Investment Thesis", "Cap Table & Valuation",
          "Exit Strategy", "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Investment Memo Title": "Generate a premium investment proposal title specifying the company name and round series. Maximum 12 words.",
          "Executive Summary": "Summarize company achievements, the funding round parameters, investment thesis, key milestones, and exit expectations.",
          "Company Overview": "Describe the corporate history, core product offering, organizational chart, and technology platform.",
          "Market Opportunity": "Analyze market sizing (TAM, SAM, SOM), macroeconomic catalysts, target customer segments, and competitor pricing.",
          "Financial Performance": "Evaluate current/historical balance sheets, profit & loss statement (P&L), gross margins, and burn rate, using data audit.",
          "Investment Thesis": "Synthesize the primary reasons for investing, including key advantages, defensible moats, and operational leverage points.",
          "Cap Table & Valuation": "Detail pre-money/post-money valuations, share allocations, option pools, and investor distributions.",
          "Exit Strategy": "Map potential acquisition targets, historical sector multiples, IPO timelines, and strategic return on investment scenarios.",
          "References": "List all financial, demographic, and technology audits cited.",
        };
        break;

      case "Socioeconomic Survey Report":
        defaultTitles = [
          "Survey Title", "Executive Summary", "Demographic Profile", "Survey Methodology",
          "Statistical Findings", "Socioeconomic Discrepancies", "Recommendations",
          "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Survey Title": "Provide a comprehensive survey report title specifying demographic group and census period. Maximum 15 words.",
          "Executive Summary": "Summarize survey objectives, sample sizes, primary demographic indicators, core correlations, and policy actions.",
          "Demographic Profile": "Elucidate age, gender, education, income, and geographic distributions of respondents, backed by survey datasets.",
          "Survey Methodology": "Detail sampling frameworks (e.g. stratified random sampling), confidence intervals, survey tools, and variance bounds.",
          "Statistical Findings": "Analyze demographic correlations, statistical tests (e.g., chi-square, t-tests), and regression analyses of income/education factors.",
          "Socioeconomic Discrepancies": "Interpret systemic differences in resource access, income equity, or services distribution among cohorts, citing research.",
          "Recommendations": "Formulate evidence-based community interventions and programmatic improvements to address disparities.",
          "References": "List all survey tools, government census documents, and sociological literature cited.",
        };
        break;

      case "System Security Audit":
        defaultTitles = [
          "Security Audit Title", "Executive Summary", "Threat Modeling", "Penetration Vector Audit",
          "Compliance & Governance (GDPR/SOC2)", "Mitigation Roadmap",
          "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Security Audit Title": "Generate an official, system-specific security audit title specifying systems analyzed. Maximum 15 words.",
          "Executive Summary": "Summarize vulnerability counts, critical threat vectors, regulatory compliance gaps, and security baseline scores.",
          "Threat Modeling": "Map the system attack surface, trust boundaries, network topologies, and data flows using frameworks like STRIDE.",
          "Penetration Vector Audit": "Document simulated penetration testing, highlighting SQL injections, CORS vulnerabilities, or access control failures.",
          "Compliance & Governance (GDPR/SOC2)": "Audit system configuration against GDPR privacy, SOC2 Trust Security Principles, or ISO 27001 checklists.",
          "Mitigation Roadmap": "Formulate a prioritized remediation schedule (immediate, short-term, long-term) with concrete engineering steps.",
          "References": "List all cybersecurity frameworks, CVE records, and cloud security compliance specs cited.",
        };
        break;

      case "UX Research Plan":
        defaultTitles = [
          "Plan Title", "Background", "Research Objectives", "User Demographics",
          "Methodology (Heuristics)", "Usability Test Setup", "Findings & Recommendation",
          "References", "Reviewer comments", "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Plan Title": "Provide a specialized user experience research plan title. Maximum 15 words.",
          "Background": "Describe product usability history, customer complaints, churn rates, or redesign goals prompting this audit.",
          "Research Objectives": "List the core usability, accessibility, and operational goals of this user test or heuristic audit.",
          "User Demographics": "Define target participant screeners, behavioral archetypes, and user recruiting targets.",
          "Methodology (Heuristics)": "Explain usability research methods utilized, such as Nielsen's heuristic evaluations, A/B testing, or card sorting.",
          "Usability Test Setup": "Detail test scenarios, user tasks, interactive mockups, and success metric bounds (e.g., Task Success Rate, System Usability Scale).",
          "Findings & Recommendation": "Summarize quantitative user test results, friction points, task completion speeds, and visual design recommendations.",
          "References": "Provide complete citations to UX research, design standards, and academic usability papers.",
        };
        break;

      default: // "Academic Manuscript"
        defaultTitles = [
          "Title", "Abstract", "Keywords", "Authors", "Introduction", 
          "Literature Review", "Methodology", "Results", "Discussion", 
          "Conclusion", "References", "Appendices", "Reviewer comments",
          "AI Detection", "Similarity"
        ];
        defaultInstructions = {
          "Title": "Generate a concise, impactful academic title reflecting the core scientific focus and findings of the analysis. Avoid generic filler words. Maximum 15 words.",
          "Abstract": "Summarize the research problem, the methodology deployed, the key quantitative findings, and broader implications in a single cohesive paragraph (under 250 words). Do NOT use citations in the abstract.",
          "Keywords": "Provide 5 to 7 highly specific, comma-separated keywords optimized for academic search indexing.",
          "Authors": "Format the author names and affiliations accurately.",
          "Introduction": "Write a comprehensive introduction. You MUST include in-text citations from the CITATION SOURCE MATERIAL using the chosen citation style. For EVERY claim or background statement, cite the relevant author(s) by surname and year, e.g. (Kirui et al., 2021) or (Landskron & Böhm, 2017). Do NOT write generic phrases like 'as discussed in general literature'. Cite the ACTUAL authors from the provided documents. The Introduction MUST contain multiple in-text citations from the source material.",
          "Literature Review": "Synthesize ALL provided source documents. You MUST cite EVERY SINGLE document from the CITATION SOURCE MATERIAL by author surname and year using the chosen citation style. Each document MUST appear at least once as an in-text citation. Compare and contrast findings across documents.",
          "Methodology": "Detail the specific algorithms, datasets, tools, and procedures used. Reference methodological approaches from the CITATION SOURCE MATERIAL where applicable, citing by author and year.",
          "Results": "Present findings objectively using quantitative statistical data extracted from the context. Cite source documents when comparing results.",
          "Discussion": "Interpret the results by explicitly referencing findings from the CITATION SOURCE MATERIAL. You MUST cite specific authors when comparing or contextualizing your findings. Discuss limitations and unexpected findings.",
          "Conclusion": "Provide a definitive concluding synthesis of the impact of the findings. Do NOT introduce new references or claims.",
          "References": "List EVERY document from the CITATION SOURCE MATERIAL as a formatted reference entry. Use the exact author names, year, title, and URL/DOI from the source documents. Every single entry MUST be present. If the year or source is not explicitly listed, extract it from the text yourself. Do NOT output '(Year)' or 'Source information missing'. Do NOT fabricate references that are not in the source material.",
        };
    }

    String accumulatedPrompt = "";
    for (int i = 0; i < defaultTitles.length; i++) {
      final title = defaultTitles[i];
      final instruction = defaultInstructions[title] ?? "";
      final initialContent = (i == 0) ? this.title : "";
      
      if (instruction.isNotEmpty) {
        final formattedInstruction = "[$title]: $instruction";
        if (accumulatedPrompt.isNotEmpty) {
          accumulatedPrompt += "\n\n$formattedInstruction";
        } else {
          accumulatedPrompt = formattedInstruction;
        }
      }
      
      sections.add(ManuscriptSection(
        title: title,
        content: initialContent,
        order: i,
        customPrompt: accumulatedPrompt.isNotEmpty ? accumulatedPrompt : instruction,
      ));
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'projectType': projectType,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'litReview': litReview,
      'methodology': methodology,
      'analysis': analysis,
      'finalManuscript': finalManuscript,
      'sections': sections.map((s) => s.toJson()).toList(),
      'manuscriptSections': manuscriptSections,
      'reviewerFeedback': reviewerFeedback,
      'lastCompletedStage': lastCompletedStage,
      'files': files.map((f) => f.toJson()).toList(),
      'agentChats': agentChats.map((k, v) => MapEntry(k.toString(), v.map((m) => m.toJson()).toList())),
      'citationStyle': citationStyle,
      'dataAnalysisModel': dataAnalysisModel,
      'isAutonomousProactive': isAutonomousProactive,
      'isDraftRefinementMode': isDraftRefinementMode,
      'extraInstructions': extraInstructions,
      'initialDraft': initialDraft,
      'reviewerInstructions': reviewerInstructions,
      'totalTokensUsed': totalTokensUsed,
    };
  }

  factory ResearchProject.fromJson(Map<String, dynamic> json) {
    final project = ResearchProject(
      id: json['id'] as String?,
      title: json['title'] as String,
      projectType: json['projectType'] as String? ?? "Academic Manuscript",
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
    );
    project.litReview = json['litReview'] ?? "";
    project.methodology = json['methodology'] ?? "";
    project.analysis = json['analysis'] ?? "";
    project.finalManuscript = json['finalManuscript'] ?? "";
    
    if (json['sections'] != null) {
      project.sections = (json['sections'] as List).map((s) => ManuscriptSection.fromJson(s as Map<String, dynamic>)).toList();
    } else if (json['manuscriptSections'] != null) {
      // Legacy migration
      project.manuscriptSections = Map<String, String>.from(json['manuscriptSections']);
      int order = 0;
      project.manuscriptSections.forEach((key, value) {
        // Try to update existing default sections if they match, or append
        final existingIdx = project.sections.indexWhere((s) => s.title.toLowerCase() == key.toLowerCase());
        if (existingIdx != -1) {
          project.sections[existingIdx].content = value;
        } else {
          project.sections.add(ManuscriptSection(title: key, content: value, order: 100 + order));
          order++;
        }
      });
    }

    project.reviewerFeedback = json['reviewerFeedback'] ?? "";
    project.lastCompletedStage = json['lastCompletedStage'] ?? "";
    project.files = (json['files'] as List?)?.map((f) => ResearchFile.fromJson(f)).toList() ?? [];
    
    if (json['agentChats'] != null) {
      final chatsMap = json['agentChats'] as Map<String, dynamic>;
      project.agentChats = chatsMap.map((k, v) => MapEntry(
        int.parse(k),
        (v as List).map((m) => ChatMessage.fromJson(m)).toList(),
      ));
    }
    
    project.citationStyle = json['citationStyle'] ?? "APA";
    project.dataAnalysisModel = json['dataAnalysisModel'] as String?;
    project.isAutonomousProactive = json['isAutonomousProactive'] ?? json['isProactive'] ?? true;
    project.isDraftRefinementMode = json['isDraftRefinementMode'] ?? json['isRefinement'] ?? false;
    project.extraInstructions = json['extraInstructions'] ?? "";
    project.initialDraft = json['initialDraft'] ?? json['userDraft'] ?? "";
    project.reviewerInstructions = json['reviewerInstructions'] ?? json['reviewerComments'] ?? "";
    project.totalTokensUsed = json['totalTokensUsed'] ?? 0;
    
    return project;
  }
}
