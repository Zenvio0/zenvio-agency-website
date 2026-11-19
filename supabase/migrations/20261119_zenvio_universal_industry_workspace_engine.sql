-- ZENVIO ONE Universal Industry & Workspace Engine v1
-- Additive foundation. Does not alter or delete existing CRM, admin, or workspace records.
-- Apply only after review and after prerequisite ZENVIO ONE + owner-management migrations.

begin;

create table if not exists public.zenvio_industry_catalog (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.zenvio_industry_catalog(id) on delete restrict,
  level text not null check (level in ('industry','sub_industry')),
  name text not null check (char_length(trim(name)) between 2 and 140),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  description text,
  default_modules text[] not null default array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics']::text[],
  dashboard_layout jsonb not null default '{"version":1,"layout":"industry_default"}'::jsonb
    check (jsonb_typeof(dashboard_layout) = 'object'),
  aria_profile jsonb not null default '{"tone":"professional","mode":"industry_assistant"}'::jsonb
    check (jsonb_typeof(aria_profile) = 'object'),
  knowledge_profile jsonb not null default '{"guidance":"Use approved company information only.","sources":[]}'::jsonb
    check (jsonb_typeof(knowledge_profile) = 'object'),
  experience_profile jsonb not null default '{"environment":"none","theme":"dark"}'::jsonb
    check (jsonb_typeof(experience_profile) = 'object'),
  approval_status text not null default 'draft' check (approval_status in ('draft','approved')),
  is_active boolean not null default true,
  is_published boolean not null default false,
  sort_order integer not null default 100,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint zenvio_industry_parent_level_check check (
    (level = 'industry' and parent_id is null) or
    (level = 'sub_industry' and parent_id is not null)
  )
);

create index if not exists zenvio_industry_parent_idx
  on public.zenvio_industry_catalog(parent_id, sort_order, name);

alter table public.zenvio_organizations
  add column if not exists industry_node_id uuid
    references public.zenvio_industry_catalog(id) on delete set null,
  add column if not exists sub_industry_node_id uuid
    references public.zenvio_industry_catalog(id) on delete set null,
  add column if not exists business_type text,
  add column if not exists industry_profile jsonb not null default '{}'::jsonb;

create table if not exists public.zenvio_workspace_profiles (
  dashboard_layout jsonb not null default '{"version":1,"layout":"industry_default","widgets":[]}'::jsonb check (jsonb_typeof(dashboard_layout) = 'object'),
  knowledge_profile jsonb not null default '{"guidance":"Use approved company information only.","sources":[]}'::jsonb check (jsonb_typeof(knowledge_profile) = 'object'),
  experience_profile jsonb not null default '{"environment":"none","theme":"dark"}'::jsonb check (jsonb_typeof(experience_profile) = 'object'),
  organization_id uuid primary key references public.zenvio_organizations(id) on delete cascade,
  industry_id uuid references public.zenvio_industry_catalog(id) on delete set null,
  sub_industry_id uuid references public.zenvio_industry_catalog(id) on delete set null,
  business_type text not null,
  company_size text,
  website_url text,
  location text,
  description text,
  services jsonb not null default '[]'::jsonb check (jsonb_typeof(services) = 'array'),
  preferences jsonb not null default '{}'::jsonb check (jsonb_typeof(preferences) = 'object'),
  aria_profile jsonb not null default '{}'::jsonb check (jsonb_typeof(aria_profile) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.zenvio_workspace_modules (
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  module_key text not null check (module_key ~ '^[a-z][a-z0-9_]{1,50}$'),
  enabled boolean not null default true,
  source text not null default 'industry_default'
    check (source in ('industry_default','owner_enabled','owner_disabled','super_admin')),
  configuration jsonb not null default '{}'::jsonb
    check (jsonb_typeof(configuration) = 'object'),
  updated_at timestamptz not null default now(),
  primary key (organization_id, module_key)
);

create table if not exists public.zenvio_industry_suggestions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.zenvio_organizations(id) on delete set null,
  submitted_by uuid not null references auth.users(id) on delete cascade,
  parent_node_id uuid references public.zenvio_industry_catalog(id) on delete set null,
  proposed_level text not null check (proposed_level in ('industry','sub_industry')),
  proposed_name text not null check (char_length(trim(proposed_name)) between 2 and 140),
  reason text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists zenvio_industry_suggestions_status_idx
  on public.zenvio_industry_suggestions(status, created_at desc);

-- Seed the 40 major industry groups. Existing slugs are stable identifiers.
insert into public.zenvio_industry_catalog
  (level, name, slug, description, default_modules, sort_order)
values
('industry','Property, Real Estate & Infrastructure','property-real-estate-infrastructure','Property agencies, ownership, development and built environments.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','booking','3d_experience'],10),
('industry','Hospitality & Accommodation','hospitality-accommodation','Hotels, stays, guest services and accommodation operators.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','booking'],20),
('industry','Food, Beverage & Restaurants','food-beverage-restaurants','Food service, restaurants, catering and food production.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','commerce','booking'],30),
('industry','Retail & Consumer Goods','retail-consumer-goods','Physical retail, consumer products and store operations.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','commerce','inventory'],40),
('industry','E-commerce & Digital Commerce','ecommerce-digital-commerce','Online stores, marketplaces and digital commerce.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','commerce','inventory','payments'],50),
('industry','Healthcare & Medical','healthcare-medical','Healthcare providers, medical services and care operations.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','booking'],60),
('industry','Education & Learning','education-learning','Schools, universities, training and learning platforms.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','learning','booking'],70),
('industry','Architecture, Design & Engineering','architecture-design-engineering','Architecture, design, engineering and visualization practices.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','projects','3d_experience'],80),
('industry','Construction & Building','construction-building','Construction, trades, contractors and building materials.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','projects','booking'],90),
('industry','Automotive & Mobility','automotive-mobility','Vehicle sales, services, mobility and automotive operations.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','inventory','booking'],100),
('industry','Travel, Tourism & Recreation','travel-tourism-recreation','Travel agencies, tourism operators and recreation experiences.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','booking'],110),
('industry','Transportation & Logistics','transportation-logistics','Freight, courier, fleet and supply-chain operations.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','logistics','inventory'],120),
('industry','Manufacturing & Industrial','manufacturing-industrial','Manufacturing, production, industrial equipment and factories.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','inventory','projects'],130),
('industry','Agriculture & Natural Resources','agriculture-natural-resources','Farming, livestock, fisheries and agricultural services.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','inventory'],140),
('industry','Energy & Utilities','energy-utilities','Energy generation, utilities, grids and water services.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','projects'],150),
('industry','Financial Services & Fintech','financial-services-fintech','Banking, finance, accounting, payments and investment services.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','projects'],160),
('industry','Legal & Compliance','legal-compliance','Legal practices, regulatory and compliance services.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','booking'],170),
('industry','Professional & Business Services','professional-business-services','Consulting, agencies and specialist business services.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','booking'],180),
('industry','Technology & Software','technology-software','Software, IT, AI, cloud and technology companies.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','projects'],190),
('industry','Media, Entertainment & Creative','media-entertainment-creative','Film, music, publishing, design and creator businesses.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','3d_experience','commerce'],200),
('industry','Sports & Fitness','sports-fitness','Sports clubs, gyms, fitness and sporting organisations.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','booking'],210),
('industry','Beauty, Fashion & Lifestyle','beauty-fashion-lifestyle','Beauty, personal care, fashion and lifestyle brands.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','booking','commerce'],220),
('industry','Events, Weddings & Entertainment Venues','events-weddings-entertainment-venues','Event planners, venues, weddings and live experiences.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','booking'],230),
('industry','Telecommunications & Communications','telecommunications-communications','Telecom, internet, network and communications providers.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','projects'],240),
('industry','Environmental & Sustainability','environmental-sustainability','Environmental services, sustainability and climate solutions.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','projects'],250),
('industry','Mining, Metals & Materials','mining-metals-materials','Mining, metals, materials and quarrying businesses.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','inventory','projects'],260),
('industry','Aerospace, Aviation & Defence','aerospace-aviation-defence','Aviation, aerospace, satellite and defence suppliers.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','projects'],270),
('industry','Government & Public Sector','government-public-sector','Public administration, government and civic services.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','projects'],280),
('industry','Nonprofit, NGOs & Social Impact','nonprofit-ngos-social-impact','Charities, foundations, humanitarian and social organisations.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','donations'],290),
('industry','Science, Research & Biotechnology','science-research-biotechnology','Scientific research, laboratories and biotechnology.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','projects'],300),
('industry','Personal, Household & Local Services','personal-household-local-services','Home services, repair, cleaning and personal services.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','booking'],310),
('industry','Human Resources & Employment','human-resources-employment','Recruitment, staffing, workforce and career services.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio'],320),
('industry','Insurance & Risk Management','insurance-risk-management','Insurance providers, claims and risk advisory.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio'],330),
('industry','Wholesale, Distribution & Trade','wholesale-distribution-trade','Wholesale, importing, exporting and distribution.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','inventory','commerce'],340),
('industry','Pet, Animal & Veterinary Services','pet-animal-veterinary-services','Veterinary, animal care and pet services.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','booking'],350),
('industry','Marine & Maritime','marine-maritime','Shipping, ports, shipbuilding and marine services.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','projects','logistics'],360),
('industry','Security & Safety','security-safety','Physical security, fire safety and occupational safety.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','projects'],370),
('industry','Research, Consulting & Intelligence','research-consulting-intelligence','Market research, intelligence and strategic consulting.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio'],380),
('industry','Sports, Gaming & Digital Communities','sports-gaming-digital-communities','Esports, gaming, virtual worlds and digital communities.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio','commerce'],390),
('industry','Other & Emerging Industries','other-emerging-industries','New, hybrid and future business models not yet classified.',array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics','website_studio'],400)
on conflict (slug) do update
set name = excluded.name,
    description = excluded.description,
    default_modules = excluded.default_modules,
    sort_order = excluded.sort_order,
    updated_at = now();


-- Industry-specific dashboard starter layouts; widgets are configuration slots, not active engines.
update public.zenvio_industry_catalog set dashboard_layout =
case slug
when 'property-real-estate-infrastructure' then '{"version":1,"layout":"real_estate","widgets":["properties","leads","viewings","commissions"]}'::jsonb
when 'hospitality-accommodation' then '{"version":1,"layout":"hospitality","widgets":["rooms","reservations","guests","occupancy"]}'::jsonb
when 'food-beverage-restaurants' then '{"version":1,"layout":"food_service","widgets":["orders","menu","bookings","revenue"]}'::jsonb
when 'retail-consumer-goods' then '{"version":1,"layout":"retail","widgets":["products","inventory","sales","customers"]}'::jsonb
when 'ecommerce-digital-commerce' then '{"version":1,"layout":"commerce","widgets":["products","orders","customers","sales"]}'::jsonb
when 'healthcare-medical' then '{"version":1,"layout":"healthcare","widgets":["appointments","services","staff","operations"]}'::jsonb
when 'education-learning' then '{"version":1,"layout":"education","widgets":["learners","courses","enrolments","progress"]}'::jsonb
when 'architecture-design-engineering' then '{"version":1,"layout":"studio","widgets":["projects","proposals","clients","deliverables"]}'::jsonb
when 'construction-building' then '{"version":1,"layout":"construction","widgets":["projects","sites","teams","milestones"]}'::jsonb
when 'automotive-mobility' then '{"version":1,"layout":"automotive","widgets":["vehicles","service_bookings","leads","sales"]}'::jsonb
when 'travel-tourism-recreation' then '{"version":1,"layout":"travel","widgets":["trips","bookings","guests","revenue"]}'::jsonb
when 'transportation-logistics' then '{"version":1,"layout":"logistics","widgets":["shipments","fleet","deliveries","exceptions"]}'::jsonb
when 'manufacturing-industrial' then '{"version":1,"layout":"manufacturing","widgets":["production","inventory","quality","orders"]}'::jsonb
when 'agriculture-natural-resources' then '{"version":1,"layout":"agriculture","widgets":["seasons","livestock","harvest","resources"]}'::jsonb
when 'energy-utilities' then '{"version":1,"layout":"utilities","widgets":["assets","consumption","outages","service_requests"]}'::jsonb
when 'financial-services-fintech' then '{"version":1,"layout":"finance","widgets":["clients","accounts","transactions","risk"]}'::jsonb
when 'legal-compliance' then '{"version":1,"layout":"legal","widgets":["matters","clients","deadlines","documents"]}'::jsonb
when 'professional-business-services' then '{"version":1,"layout":"professional_services","widgets":["clients","projects","proposals","billable_work"]}'::jsonb
when 'technology-software' then '{"version":1,"layout":"technology","widgets":["products","projects","incidents","releases"]}'::jsonb
when 'media-entertainment-creative' then '{"version":1,"layout":"creative","widgets":["projects","productions","assets","publishing"]}'::jsonb
when 'sports-fitness' then '{"version":1,"layout":"fitness","widgets":["members","sessions","coaches","attendance"]}'::jsonb
when 'beauty-fashion-lifestyle' then '{"version":1,"layout":"beauty_lifestyle","widgets":["appointments","services","products","customers"]}'::jsonb
when 'events-weddings-entertainment-venues' then '{"version":1,"layout":"events","widgets":["events","bookings","vendors","guests"]}'::jsonb
when 'telecommunications-communications' then '{"version":1,"layout":"telecom","widgets":["subscribers","services","incidents","network"]}'::jsonb
when 'environmental-sustainability' then '{"version":1,"layout":"sustainability","widgets":["projects","impact","audits","resources"]}'::jsonb
when 'mining-metals-materials' then '{"version":1,"layout":"materials","widgets":["sites","production","inventory","safety"]}'::jsonb
when 'aerospace-aviation-defence' then '{"version":1,"layout":"aerospace","widgets":["programs","assets","maintenance","compliance"]}'::jsonb
when 'government-public-sector' then '{"version":1,"layout":"public_sector","widgets":["services","cases","departments","performance"]}'::jsonb
when 'nonprofit-ngos-social-impact' then '{"version":1,"layout":"nonprofit","widgets":["programs","donors","volunteers","impact"]}'::jsonb
when 'science-research-biotechnology' then '{"version":1,"layout":"research","widgets":["studies","labs","grants","milestones"]}'::jsonb
when 'personal-household-local-services' then '{"version":1,"layout":"local_services","widgets":["jobs","bookings","technicians","customers"]}'::jsonb
when 'human-resources-employment' then '{"version":1,"layout":"hr","widgets":["candidates","roles","placements","employees"]}'::jsonb
when 'insurance-risk-management' then '{"version":1,"layout":"insurance","widgets":["policies","claims","clients","risk"]}'::jsonb
when 'wholesale-distribution-trade' then '{"version":1,"layout":"distribution","widgets":["catalogue","purchase_orders","inventory","shipments"]}'::jsonb
when 'pet-animal-veterinary-services' then '{"version":1,"layout":"veterinary","widgets":["patients","appointments","services","care_plans"]}'::jsonb
when 'marine-maritime' then '{"version":1,"layout":"maritime","widgets":["vessels","voyages","cargo","maintenance"]}'::jsonb
when 'security-safety' then '{"version":1,"layout":"security","widgets":["sites","incidents","teams","compliance"]}'::jsonb
when 'research-consulting-intelligence' then '{"version":1,"layout":"intelligence","widgets":["research","clients","insights","deliverables"]}'::jsonb
when 'sports-gaming-digital-communities' then '{"version":1,"layout":"digital_community","widgets":["members","events","content","engagement"]}'::jsonb
else '{"version":1,"layout":"emerging_business","widgets":["projects","customers","operations","insights"]}'::jsonb
end
where level = 'industry';


-- The initial reviewed catalogue is approved and published. New entries remain drafts until reviewed.
update public.zenvio_industry_catalog
set approval_status = 'approved', is_published = true
where level = 'industry';

update public.zenvio_industry_catalog
set experience_profile = case slug
  when 'property-real-estate-infrastructure' then '{"environment":"real_estate_showroom","theme":"dark"}'::jsonb
  when 'hospitality-accommodation' then '{"environment":"hotel_lobby","theme":"dark"}'::jsonb
  when 'food-beverage-restaurants' then '{"environment":"restaurant","theme":"warm"}'::jsonb
  when 'retail-consumer-goods' then '{"environment":"retail_store","theme":"dark"}'::jsonb
  when 'ecommerce-digital-commerce' then '{"environment":"digital_store","theme":"dark"}'::jsonb
  when 'healthcare-medical' then '{"environment":"clinic","theme":"calm"}'::jsonb
  when 'education-learning' then '{"environment":"learning_campus","theme":"light"}'::jsonb
  when 'architecture-design-engineering' then '{"environment":"architecture_studio","theme":"minimal"}'::jsonb
  when 'automotive-mobility' then '{"environment":"automotive_showroom","theme":"dark"}'::jsonb
  when 'media-entertainment-creative' then '{"environment":"creative_stage","theme":"cinematic"}'::jsonb
  else '{"environment":"industry_workspace","theme":"dark"}'::jsonb
end
where level = 'industry';

-- Seed broad sub-industry coverage. Owners can request missing types; Super Admin can extend this directory.
with seed(parent_slug, names) as (
  values
  ('property-real-estate-infrastructure','Residential Real Estate|Commercial Real Estate|Luxury Properties|Property Management|Real Estate Investment|Property Rentals|Co-working Spaces|Housing Societies|Smart Cities|Property Development'),
  ('hospitality-accommodation','Hotels|Resorts|Motels|Hostels|Guest Houses|Luxury Villas|Serviced Apartments|Bed & Breakfast|Vacation Rentals|Boutique Hotels'),
  ('food-beverage-restaurants','Restaurants|Cafés|Fast Food|Fine Dining|Bakeries|Cloud Kitchens|Food Trucks|Catering|Food Courts|Juice Bars|Coffee Shops|Food Manufacturing'),
  ('retail-consumer-goods','Fashion Retail|Luxury Retail|Jewellery|Electronics|Furniture|Home Decor|General Stores|Supermarkets|Department Stores|Cosmetics|Sporting Goods|Toys|Books|Pet Supplies'),
  ('ecommerce-digital-commerce','B2C E-commerce|B2B E-commerce|D2C Brands|Online Marketplaces|Subscription Commerce|Digital Products|Dropshipping|Wholesale Platforms|Social Commerce|Online Auctions'),
  ('healthcare-medical','Hospitals|Clinics|Dental Clinics|Diagnostic Laboratories|Medical Imaging|Pharmacies|Medical Equipment|Physiotherapy|Rehabilitation|Mental Wellness|Eye Care|Home Healthcare|Telemedicine|Medical Research'),
  ('education-learning','Schools|Colleges|Universities|Online Academies|Coaching Centres|Training Institutes|Language Schools|Technical Education|Vocational Training|E-learning Platforms|Educational Publishers|Research Institutions'),
  ('architecture-design-engineering','Architecture Studios|Interior Design|Landscape Design|Urban Planning|Civil Engineering|Structural Engineering|Mechanical Engineering|Electrical Engineering|Industrial Design|3D Visualization|Building Design|Sustainable Design'),
  ('construction-building','Construction Companies|Contractors|Real Estate Developers|Infrastructure Projects|Road Construction|Bridge Construction|Renovation|Roofing|Plumbing|Electrical Services|Building Materials|Smart Buildings'),
  ('automotive-mobility','Car Dealerships|Used Cars|Luxury Vehicles|Motorcycles|Electric Vehicles|Auto Parts|Auto Repair|Car Rentals|Fleet Management|Vehicle Manufacturing|Vehicle Customization|Car Washes'),
  ('travel-tourism-recreation','Travel Agencies|Tour Operators|Airlines|Cruise Operators|Adventure Tourism|Eco Tourism|Religious Tourism|Cultural Tourism|Tourism Boards|Theme Parks|Travel Experiences|Destination Management'),
  ('transportation-logistics','Freight|Shipping|Courier Services|Warehousing|Supply Chain|Cargo Handling|Public Transport|Railways|Aviation Services|Fleet Operations|Last-mile Delivery|Moving Companies'),
  ('manufacturing-industrial','Automotive Manufacturing|Electronics Manufacturing|Textile Manufacturing|Food Processing|Chemical Manufacturing|Machinery|Industrial Equipment|Packaging|Metal Fabrication|Plastics|Pharmaceuticals|Robotics|Aerospace Manufacturing'),
  ('agriculture-natural-resources','Crop Farming|Livestock|Dairy Farming|Poultry|Fisheries|Aquaculture|Horticulture|Forestry|Agricultural Equipment|Seeds & Fertilizers|Agri-Tech|Food Distribution'),
  ('energy-utilities','Solar Energy|Wind Energy|Hydropower|Oil & Gas|Electricity Providers|Nuclear Energy|Battery Storage|Energy Management|Water Utilities|Wastewater Management|Smart Grids'),
  ('financial-services-fintech','Banking|Insurance|Investment Firms|Asset Management|Accounting|Tax Consultancy|Financial Advisory|Fintech|Payment Services|Wealth Management|Microfinance|Credit Services'),
  ('legal-compliance','Law Firms|Corporate Law|Family Law|Immigration Law|Intellectual Property|Tax Law|Legal Consultancy|Compliance Services|Mediation|Notary Services|Contract Management'),
  ('professional-business-services','Management Consulting|Business Consulting|HR Consulting|Recruitment|Marketing Agencies|Digital Agencies|IT Consulting|Business Process Outsourcing|Virtual Assistance|Corporate Services|Market Research|Business Training'),
  ('technology-software','SaaS|Software Development|Mobile App Development|Web Development|AI Companies|Cybersecurity|Cloud Computing|Data Analytics|Blockchain|IoT|Telecommunications|IT Infrastructure|Game Development|Hardware Companies'),
  ('media-entertainment-creative','Film Production|Television|Music|Animation|VFX|Photography|Video Production|Graphic Design|Advertising|Publishing|Gaming|Streaming|Digital Creators|Podcasting'),
  ('sports-fitness','Gyms|Fitness Studios|Sports Clubs|Sports Academies|Professional Teams|Stadiums|Sports Equipment|Personal Trainers|Yoga|Martial Arts|Sports Events|Sports Nutrition'),
  ('beauty-fashion-lifestyle','Beauty Salons|Barbershops|Spas|Skincare|Cosmetics|Fashion Designers|Clothing Brands|Footwear|Luxury Accessories|Personal Styling|Wellness Centres|Fragrance Brands'),
  ('events-weddings-entertainment-venues','Wedding Planners|Event Management|Convention Centres|Banquet Halls|Exhibition Organizers|Concert Venues|Event Equipment Rental|Corporate Events|Party Planners|Wedding Photography'),
  ('telecommunications-communications','Mobile Networks|Internet Service Providers|Data Centres|Satellite Communications|Telecom Equipment|Communication Software|Network Infrastructure|Broadcasting Networks'),
  ('environmental-sustainability','Recycling|Waste Management|Environmental Consulting|Renewable Materials|Carbon Management|Water Conservation|Environmental Testing|Sustainability Services|Climate Technology'),
  ('mining-metals-materials','Mining|Mineral Processing|Precious Metals|Steel|Cement|Stone & Marble|Industrial Minerals|Quarrying|Metal Trading|Material Research'),
  ('aerospace-aviation-defence','Commercial Aviation|Aircraft Maintenance|Aerospace Engineering|Space Technology|Satellite Manufacturing|Drone Manufacturing|Aviation Training|Airport Services|Defence Manufacturing'),
  ('government-public-sector','Government Departments|Municipal Services|Public Administration|Public Transport Authorities|Public Utilities|Citizen Service Portals|Public Education|Public Healthcare|Smart Government'),
  ('nonprofit-ngos-social-impact','Charities|NGOs|Foundations|Humanitarian Organizations|Community Organizations|Religious Organizations|Social Enterprises|Fundraising Platforms|Volunteer Networks'),
  ('science-research-biotechnology','Biotechnology|Laboratories|Scientific Research|Pharmaceutical Research|Genetics|Nanotechnology|Material Science|Clinical Research|Research & Development|Scientific Equipment'),
  ('personal-household-local-services','Cleaning Services|Home Maintenance|Electricians|Plumbers|Pest Control|Landscaping|Laundry|Repair Services|Security Services|Personal Care|Pet Grooming|Home Automation'),
  ('human-resources-employment','Recruitment Agencies|Staffing|Executive Search|Career Coaching|Job Portals|Payroll Services|Employee Training|Workforce Management|Freelance Platforms'),
  ('insurance-risk-management','Life Insurance|Health Insurance|Property Insurance|Vehicle Insurance|Commercial Insurance|Reinsurance|Risk Consultancy|Claims Management'),
  ('wholesale-distribution-trade','Wholesale Suppliers|Importers|Exporters|Distributors|Trading Companies|Procurement|Industrial Suppliers|International Trade|B2B Marketplaces'),
  ('pet-animal-veterinary-services','Veterinary Hospitals|Veterinary Clinics|Pet Stores|Animal Shelters|Pet Boarding|Pet Grooming|Animal Nutrition|Livestock Services|Animal Breeding'),
  ('marine-maritime','Shipping Companies|Shipbuilding|Marine Engineering|Ports|Fishing|Yacht Services|Boat Rentals|Maritime Logistics|Marine Equipment'),
  ('security-safety','Security Companies|CCTV Installation|Fire Safety|Alarm Systems|Cybersecurity|Occupational Safety|Security Equipment|Emergency Management'),
  ('research-consulting-intelligence','Market Intelligence|Business Intelligence|Economic Research|Political Risk Research|Consumer Research|Data Research|Scientific Consulting|Strategy Consulting'),
  ('sports-gaming-digital-communities','Esports|Gaming Studios|Gaming Arenas|Game Publishers|Gaming Equipment|Virtual Worlds|Digital Communities|Creator Communities'),
  ('other-emerging-industries','Space Tourism|Virtual Reality|Augmented Reality|Robotics Services|Digital Twins|Metaverse Experiences|Autonomous Systems|Quantum Technology|Future Mobility|Emerging Technologies')
),
expanded as (
  select parent_slug, trim(item) as child_name
  from seed, lateral unnest(string_to_array(names, '|')) as item
)
insert into public.zenvio_industry_catalog
  (parent_id, level, name, slug, description, default_modules, dashboard_layout, aria_profile, knowledge_profile, experience_profile, approval_status, is_published, sort_order)
select
  parent.id,
  'sub_industry',
  expanded.child_name,
  parent.slug || '-' || trim(both '-' from regexp_replace(lower(expanded.child_name), '[^a-z0-9]+', '-', 'g')),
  expanded.child_name || ' business type.',
  parent.default_modules,
  parent.dashboard_layout,
  parent.aria_profile,
  parent.knowledge_profile,
  parent.experience_profile,
  parent.approval_status,
  parent.is_published,
  row_number() over (partition by parent.id order by expanded.child_name)::integer
from expanded
join public.zenvio_industry_catalog parent
  on parent.slug = expanded.parent_slug and parent.level = 'industry'
on conflict (slug) do update
set name = excluded.name,
    parent_id = excluded.parent_id,
    default_modules = excluded.default_modules,
    sort_order = excluded.sort_order,
    updated_at = now();


-- Registry distinguishes working modules from configuration-only and planned modules.
create table if not exists public.zenvio_module_registry (
  module_key text primary key check (module_key ~ '^[a-z][a-z0-9_]{1,50}
alter table public.zenvio_workspace_profiles enable row level security;
alter table public.zenvio_workspace_modules enable row level security;
alter table public.zenvio_industry_suggestions enable row level security;

revoke all on public.zenvio_industry_catalog from anon, authenticated;
revoke all on public.zenvio_workspace_profiles from anon, authenticated;
revoke all on public.zenvio_workspace_modules from anon, authenticated;
revoke all on public.zenvio_industry_suggestions from anon, authenticated;

drop policy if exists zenvio_industry_catalog_read on public.zenvio_industry_catalog;
create policy zenvio_industry_catalog_read
on public.zenvio_industry_catalog
for select to authenticated
using ((is_active and is_published) or public.zenvio_is_super_admin());

drop policy if exists zenvio_industry_catalog_super_insert on public.zenvio_industry_catalog;
create policy zenvio_industry_catalog_super_insert
on public.zenvio_industry_catalog
for insert to authenticated
with check (public.zenvio_is_super_admin());

drop policy if exists zenvio_industry_catalog_super_update on public.zenvio_industry_catalog;
create policy zenvio_industry_catalog_super_update
on public.zenvio_industry_catalog
for update to authenticated
using (public.zenvio_is_super_admin())
with check (public.zenvio_is_super_admin());

drop policy if exists zenvio_industry_catalog_super_delete on public.zenvio_industry_catalog;
create policy zenvio_industry_catalog_super_delete
on public.zenvio_industry_catalog
for delete to authenticated
using (public.zenvio_is_super_admin());

drop policy if exists zenvio_workspace_profiles_member_read on public.zenvio_workspace_profiles;
create policy zenvio_workspace_profiles_member_read
on public.zenvio_workspace_profiles
for select to authenticated
using (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_workspace_profiles_owner_insert on public.zenvio_workspace_profiles;
create policy zenvio_workspace_profiles_owner_insert
on public.zenvio_workspace_profiles
for insert to authenticated
with check (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_workspace_profiles_owner_update on public.zenvio_workspace_profiles;
create policy zenvio_workspace_profiles_owner_update
on public.zenvio_workspace_profiles
for update to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']))
with check (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_workspace_modules_member_read on public.zenvio_workspace_modules;
create policy zenvio_workspace_modules_member_read
on public.zenvio_workspace_modules
for select to authenticated
using (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_workspace_modules_owner_manage on public.zenvio_workspace_modules;
create policy zenvio_workspace_modules_owner_manage
on public.zenvio_workspace_modules
for all to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']))
with check (public.zenvio_has_role(organization_id, array['owner','admin']));

-- Enforce module registry status at the database boundary, not only in the UI.
create or replace function public.zenvio_enforce_workspace_module_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $
declare module_status text;
begin
  select implementation_status into module_status
  from public.zenvio_module_registry
  where module_key = new.module_key;

  if module_status is null then
    raise exception 'Unknown ZENVIO module: %', new.module_key;
  end if;

  if new.source = 'super_admin' and not public.zenvio_is_super_admin() then
    raise exception 'Only Super Admin may assign the super_admin module source';
  end if;

  if module_status = 'planned' then
    if new.source = 'industry_default' then
      new.enabled := false;
    elsif new.enabled then
      raise exception 'This module is planned and cannot be enabled yet';
    end if;
  end if;

  return new;
end;
$;

drop trigger if exists zenvio_workspace_module_status_guard on public.zenvio_workspace_modules;
create trigger zenvio_workspace_module_status_guard
before insert or update of module_key, enabled, source
on public.zenvio_workspace_modules
for each row execute function public.zenvio_enforce_workspace_module_status();

update public.zenvio_workspace_modules wm
set enabled = false, updated_at = now()
from public.zenvio_module_registry mr
where mr.module_key = wm.module_key
  and mr.implementation_status = 'planned'
  and wm.source = 'industry_default'
  and wm.enabled = true;

revoke all on function public.zenvio_enforce_workspace_module_status() from public, anon;

drop policy if exists zenvio_industry_suggestions_submit on public.zenvio_industry_suggestions;
create policy zenvio_industry_suggestions_submit
on public.zenvio_industry_suggestions
for insert to authenticated
with check (
  submitted_by = auth.uid()
  and (organization_id is null or public.zenvio_is_member(organization_id))
);

drop policy if exists zenvio_industry_suggestions_owner_read on public.zenvio_industry_suggestions;
create policy zenvio_industry_suggestions_owner_read
on public.zenvio_industry_suggestions
for select to authenticated
using (
  submitted_by = auth.uid()
  or public.zenvio_is_super_admin()
  or (organization_id is not null and public.zenvio_has_role(organization_id, array['owner','admin']))
);

drop policy if exists zenvio_industry_suggestions_super_update on public.zenvio_industry_suggestions;
create policy zenvio_industry_suggestions_super_update
on public.zenvio_industry_suggestions
for update to authenticated
using (public.zenvio_is_super_admin())
with check (public.zenvio_is_super_admin());

grant select on public.zenvio_industry_catalog to authenticated;
grant insert, update, delete on public.zenvio_industry_catalog to authenticated;
grant select, insert, update on public.zenvio_workspace_profiles to authenticated;
grant select, insert, update, delete on public.zenvio_workspace_modules to authenticated;
grant select on public.zenvio_industry_suggestions to authenticated;

create or replace function public.zenvio_apply_industry_workspace_defaults()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_industry public.zenvio_industry_catalog%rowtype;
  selected_sub public.zenvio_industry_catalog%rowtype;
  module_name text;
  modules_to_enable text[];
begin
  if new.industry_node_id is not null then
    select * into selected_industry
    from public.zenvio_industry_catalog
    where id = new.industry_node_id and level = 'industry' and is_active and is_published;

    if not found then
      raise exception 'Selected industry is unavailable';
    end if;
  end if;

  if new.sub_industry_node_id is not null then
    select * into selected_sub
    from public.zenvio_industry_catalog
    where id = new.sub_industry_node_id
      and level = 'sub_industry'
      and parent_id = new.industry_node_id
      and is_active and is_published;

    if not found then
      raise exception 'Selected sub-industry does not belong to the selected industry';
    end if;
  end if;

  modules_to_enable := coalesce(selected_sub.default_modules, selected_industry.default_modules,
    array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics']::text[]);

  insert into public.zenvio_workspace_profiles (
    organization_id, industry_id, sub_industry_id, business_type, aria_profile, dashboard_layout, knowledge_profile, experience_profile
  )
  values (
    new.id, new.industry_node_id, new.sub_industry_node_id,
    coalesce(nullif(trim(new.business_type), ''), 'General Business'),
    coalesce(selected_sub.aria_profile, selected_industry.aria_profile, '{"tone":"professional","mode":"industry_assistant"}'::jsonb),
    coalesce(selected_sub.dashboard_layout, selected_industry.dashboard_layout, '{"version":1,"layout":"industry_default","widgets":[]}'::jsonb),
    coalesce(selected_sub.knowledge_profile, selected_industry.knowledge_profile, '{"guidance":"Use approved company information only.","sources":[]}'::jsonb),
    coalesce(selected_sub.experience_profile, selected_industry.experience_profile, '{"environment":"none","theme":"dark"}'::jsonb)
  )
  on conflict (organization_id) do update
  set industry_id = excluded.industry_id,
      sub_industry_id = excluded.sub_industry_id,
      business_type = excluded.business_type,
      aria_profile = excluded.aria_profile,
      dashboard_layout = excluded.dashboard_layout,
      knowledge_profile = excluded.knowledge_profile,
      experience_profile = excluded.experience_profile,
      updated_at = now();

  foreach module_name in array modules_to_enable loop
    insert into public.zenvio_workspace_modules(organization_id, module_key, enabled, source)
    values (new.id, module_name, true, 'industry_default')
    on conflict (organization_id, module_key) do nothing;
  end loop;

  return new;
end;
$$;

drop trigger if exists zenvio_org_industry_defaults on public.zenvio_organizations;
create trigger zenvio_org_industry_defaults
after insert or update of industry_node_id, sub_industry_node_id, business_type
on public.zenvio_organizations
for each row execute function public.zenvio_apply_industry_workspace_defaults();

-- Backfill workspace profiles and industry defaults for organizations created before this migration.
insert into public.zenvio_workspace_profiles (
  organization_id, industry_id, sub_industry_id, business_type,
  aria_profile, knowledge_profile, experience_profile, dashboard_layout
)
select
  o.id, i.id, si.id,
  coalesce(nullif(trim(o.business_type), ''), 'General Business'),
  coalesce(si.aria_profile, i.aria_profile, '{"tone":"professional","mode":"industry_assistant"}'::jsonb),
  coalesce(si.knowledge_profile, i.knowledge_profile, '{"guidance":"Use approved company information only.","sources":[]}'::jsonb),
  coalesce(si.experience_profile, i.experience_profile, '{"environment":"none","theme":"dark"}'::jsonb),
  coalesce(si.dashboard_layout, i.dashboard_layout, '{"version":1,"layout":"industry_default","widgets":[]}'::jsonb)
from public.zenvio_organizations o
left join public.zenvio_industry_catalog i
  on i.id = o.industry_node_id and i.level = 'industry'
left join public.zenvio_industry_catalog si
  on si.id = o.sub_industry_node_id and si.level = 'sub_industry' and si.parent_id = i.id
on conflict (organization_id) do nothing;

insert into public.zenvio_workspace_modules (organization_id, module_key, enabled, source)
select o.id, module_key, true, 'industry_default'
from public.zenvio_organizations o
left join public.zenvio_industry_catalog i on i.id = o.industry_node_id
left join public.zenvio_industry_catalog si on si.id = o.sub_industry_node_id
cross join lateral unnest(coalesce(
  si.default_modules, i.default_modules,
  array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics']::text[]
)) as module_key
on conflict (organization_id, module_key) do nothing;


create or replace function public.zenvio_guard_workspace_profile_taxonomy_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (
    new.industry_id is distinct from old.industry_id
    or new.sub_industry_id is distinct from old.sub_industry_id
    or new.business_type is distinct from old.business_type
    or new.dashboard_layout is distinct from old.dashboard_layout
    or new.knowledge_profile is distinct from old.knowledge_profile
    or new.experience_profile is distinct from old.experience_profile
    or new.aria_profile is distinct from old.aria_profile
  ) and coalesce(current_setting('zenvio.industry_change_approved', true), '') <> 'yes' then
    raise exception 'Industry taxonomy and dashboard layout are managed by the approved industry workflow';
  end if;
  return new;
end;
$$;

drop trigger if exists zenvio_workspace_profile_taxonomy_guard on public.zenvio_workspace_profiles;
create trigger zenvio_workspace_profile_taxonomy_guard
before update of industry_id, sub_industry_id, business_type, dashboard_layout, knowledge_profile, experience_profile, aria_profile
on public.zenvio_workspace_profiles
for each row execute function public.zenvio_guard_workspace_profile_taxonomy_change();

drop trigger if exists zenvio_workspace_profiles_touch on public.zenvio_workspace_profiles;
create trigger zenvio_workspace_profiles_touch
before update on public.zenvio_workspace_profiles
for each row execute function public.zenvio_touch_updated_at();

create or replace function public.zenvio_submit_industry_suggestion(
  p_organization_id uuid,
  p_parent_node_id uuid,
  p_proposed_level text,
  p_proposed_name text,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare suggestion_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_organization_id is not null
     and not public.zenvio_is_member(p_organization_id) then
    raise exception 'Workspace membership required';
  end if;

  if p_proposed_level not in ('industry','sub_industry') then
    raise exception 'Invalid industry level';
  end if;

  if char_length(trim(coalesce(p_proposed_name, ''))) not between 2 and 140 then
    raise exception 'Enter a valid industry name';
  end if;

  if p_proposed_level = 'industry' and p_parent_node_id is not null then
    raise exception 'A top-level industry cannot have a parent';
  end if;

  if p_proposed_level = 'sub_industry' and not exists (
    select 1 from public.zenvio_industry_catalog
    where id = p_parent_node_id and level = 'industry' and is_active
  ) then
    raise exception 'Select a valid parent industry';
  end if;

  insert into public.zenvio_industry_suggestions(
    organization_id, submitted_by, parent_node_id, proposed_level, proposed_name, reason
  )
  values (
    p_organization_id, auth.uid(), p_parent_node_id, p_proposed_level,
    trim(p_proposed_name), nullif(trim(coalesce(p_reason, '')), '')
  )
  returning id into suggestion_id;

  return suggestion_id;
end;
$$;

revoke all on function public.zenvio_submit_industry_suggestion(uuid, uuid, text, text, text)
from public, anon;
grant execute on function public.zenvio_submit_industry_suggestion(uuid, uuid, text, text, text)
to authenticated;

create or replace function public.zenvio_review_industry_suggestion(
  p_suggestion_id uuid,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  suggestion public.zenvio_industry_suggestions%rowtype;
  new_node_id uuid;
  parent_slug text;
  new_slug text;
begin
  if not public.zenvio_is_super_admin() then
    raise exception 'Super Admin access required';
  end if;

  if p_decision not in ('approve','reject') then
    raise exception 'Decision must be approve or reject';
  end if;

  select * into suggestion
  from public.zenvio_industry_suggestions
  where id = p_suggestion_id and status = 'pending'
  for update;

  if not found then
    raise exception 'Pending suggestion not found';
  end if;

  if p_decision = 'reject' then
    update public.zenvio_industry_suggestions
    set status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now()
    where id = p_suggestion_id;
    return jsonb_build_object('status','rejected');
  end if;

  if suggestion.proposed_level = 'sub_industry' then
    select slug into parent_slug from public.zenvio_industry_catalog
    where id = suggestion.parent_node_id and level = 'industry';
    if parent_slug is null then raise exception 'Parent industry no longer exists'; end if;
    new_slug := parent_slug || '-' || trim(both '-' from regexp_replace(lower(suggestion.proposed_name), '[^a-z0-9]+', '-', 'g'));
  else
    new_slug := trim(both '-' from regexp_replace(lower(suggestion.proposed_name), '[^a-z0-9]+', '-', 'g'));
  end if;

  insert into public.zenvio_industry_catalog(
    parent_id, level, name, slug, description, created_by, sort_order
  )
  values (
    case when suggestion.proposed_level = 'sub_industry' then suggestion.parent_node_id else null end,
    suggestion.proposed_level,
    suggestion.proposed_name,
    new_slug,
    'Added from owner industry suggestion.',
    auth.uid(),
    900
  )
  returning id into new_node_id;

  if suggestion.proposed_level = 'sub_industry' then
    update public.zenvio_industry_catalog child
    set default_modules = parent.default_modules,
        dashboard_layout = parent.dashboard_layout,
        aria_profile = parent.aria_profile,
        knowledge_profile = parent.knowledge_profile,
        experience_profile = parent.experience_profile,
        approval_status = 'draft',
        is_published = false
    from public.zenvio_industry_catalog parent
    where child.id = new_node_id and parent.id = suggestion.parent_node_id;
  end if;

  update public.zenvio_industry_suggestions
  set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_suggestion_id;

  return jsonb_build_object('status','approved','industry_node_id',new_node_id);
end;
$$;

revoke all on function public.zenvio_review_industry_suggestion(uuid, text)
from public, anon;
grant execute on function public.zenvio_review_industry_suggestion(uuid, text)
to authenticated;


-- Industry changes use an explicit request/review workflow; browser updates cannot bypass it.
create table if not exists public.zenvio_industry_change_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  requested_by uuid not null references auth.users(id) on delete restrict,
  current_industry_id uuid references public.zenvio_industry_catalog(id) on delete set null,
  current_sub_industry_id uuid references public.zenvio_industry_catalog(id) on delete set null,
  proposed_industry_id uuid not null references public.zenvio_industry_catalog(id) on delete restrict,
  proposed_sub_industry_id uuid not null references public.zenvio_industry_catalog(id) on delete restrict,
  proposed_business_type text not null check (char_length(trim(proposed_business_type)) between 2 and 140),
  reason text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.zenvio_industry_change_requests enable row level security;
revoke all on public.zenvio_industry_change_requests from anon, authenticated;

drop policy if exists zenvio_industry_change_request_read on public.zenvio_industry_change_requests;
create policy zenvio_industry_change_request_read
on public.zenvio_industry_change_requests
for select to authenticated
using (
  public.zenvio_is_super_admin()
  or public.zenvio_has_role(organization_id, array['owner','admin'])
);

grant select on public.zenvio_industry_change_requests to authenticated;

create or replace function public.zenvio_guard_industry_profile_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (
    new.industry is distinct from old.industry
    or new.industry_node_id is distinct from old.industry_node_id
    or new.sub_industry_node_id is distinct from old.sub_industry_node_id
    or new.business_type is distinct from old.business_type
  ) and coalesce(current_setting('zenvio.industry_change_approved', true), '') <> 'yes' then
    raise exception 'Industry changes must be submitted for review from the workspace settings';
  end if;
  return new;
end;
$$;

drop trigger if exists zenvio_org_industry_change_guard on public.zenvio_organizations;
create trigger zenvio_org_industry_change_guard
before update of industry, industry_node_id, sub_industry_node_id, business_type
on public.zenvio_organizations
for each row execute function public.zenvio_guard_industry_profile_change();

create or replace function public.zenvio_request_industry_change(
  p_organization_id uuid,
  p_industry_id uuid,
  p_sub_industry_id uuid,
  p_business_type text,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_org public.zenvio_organizations%rowtype;
  new_request_id uuid;
begin
  if auth.uid() is null or not public.zenvio_has_role(p_organization_id, array['owner','admin']) then
    raise exception 'Workspace owner/admin access required';
  end if;

  select * into current_org
  from public.zenvio_organizations
  where id = p_organization_id
  for update;

  if not found then raise exception 'Workspace not found'; end if;

  if not exists (
    select 1 from public.zenvio_industry_catalog
    where id = p_industry_id and level = 'industry' and is_active and is_published
  ) then raise exception 'Choose a published industry'; end if;

  if not exists (
    select 1 from public.zenvio_industry_catalog
    where id = p_sub_industry_id and parent_id = p_industry_id
      and level = 'sub_industry' and is_active and is_published
  ) then raise exception 'Choose a sub-industry under the selected industry'; end if;

  if char_length(trim(coalesce(p_business_type, ''))) not between 2 and 140 then
    raise exception 'Enter a valid business type';
  end if;

  if exists (
    select 1 from public.zenvio_industry_change_requests
    where organization_id = p_organization_id and status = 'pending'
  ) then raise exception 'A workspace industry change is already awaiting review'; end if;

  insert into public.zenvio_industry_change_requests(
    organization_id, requested_by, current_industry_id, current_sub_industry_id,
    proposed_industry_id, proposed_sub_industry_id, proposed_business_type, reason
  )
  values (
    p_organization_id, auth.uid(), current_org.industry_node_id, current_org.sub_industry_node_id,
    p_industry_id, p_sub_industry_id, trim(p_business_type), nullif(trim(coalesce(p_reason, '')), '')
  )
  returning id into new_request_id;

  return new_request_id;
end;
$$;

create or replace function public.zenvio_review_industry_change(
  p_request_id uuid,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  change_request public.zenvio_industry_change_requests%rowtype;
  target_industry public.zenvio_industry_catalog%rowtype;
  target_sub public.zenvio_industry_catalog%rowtype;
  module_name text;
  next_modules text[];
begin
  if not public.zenvio_is_super_admin() then raise exception 'Super Admin access required'; end if;
  if p_decision not in ('approve','reject') then raise exception 'Decision must be approve or reject'; end if;

  select * into change_request
  from public.zenvio_industry_change_requests
  where id = p_request_id and status = 'pending'
  for update;

  if not found then raise exception 'Pending industry change request not found'; end if;

  if p_decision = 'reject' then
    update public.zenvio_industry_change_requests
    set status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now()
    where id = p_request_id;
    return pg_catalog.jsonb_build_object('status','rejected');
  end if;

  select * into target_industry
  from public.zenvio_industry_catalog
  where id = change_request.proposed_industry_id and level = 'industry'
    and is_active and is_published;
  if not found then raise exception 'Proposed industry is no longer available'; end if;

  select * into target_sub
  from public.zenvio_industry_catalog
  where id = change_request.proposed_sub_industry_id
    and parent_id = target_industry.id and level = 'sub_industry'
    and is_active and is_published;
  if not found then raise exception 'Proposed sub-industry is no longer available'; end if;

  perform pg_catalog.set_config('zenvio.industry_change_approved','yes',true);

  update public.zenvio_organizations
  set industry = target_industry.name || ' / ' || target_sub.name,
      industry_node_id = target_industry.id,
      sub_industry_node_id = target_sub.id,
      business_type = change_request.proposed_business_type
  where id = change_request.organization_id;

  next_modules := target_sub.default_modules;

  update public.zenvio_workspace_modules
  set enabled = false, source = 'industry_default', updated_at = now()
  where organization_id = change_request.organization_id
    and source = 'industry_default'
    and not (module_key = any(next_modules));

  foreach module_name in array next_modules loop
    insert into public.zenvio_workspace_modules(organization_id, module_key, enabled, source)
    values (change_request.organization_id, module_name, true, 'industry_default')
    on conflict (organization_id, module_key) do update
    set enabled = true, updated_at = now()
    where public.zenvio_workspace_modules.source = 'industry_default';
  end loop;

  update public.zenvio_industry_change_requests
  set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_request_id;

  return pg_catalog.jsonb_build_object('status','approved','organization_id',change_request.organization_id);
end;
$$;

revoke all on function public.zenvio_request_industry_change(uuid, uuid, uuid, text, text) from public, anon;
revoke all on function public.zenvio_review_industry_change(uuid, text) from public, anon;
grant execute on function public.zenvio_request_industry_change(uuid, uuid, uuid, text, text) to authenticated;
grant execute on function public.zenvio_review_industry_change(uuid, text) to authenticated;


create or replace function public.zenvio_industry_platform_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare result jsonb;
begin
  if not public.zenvio_is_super_admin() then
    raise exception 'Super Admin access required';
  end if;

  select coalesce(pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'organization_id', o.id,
      'organization_name', o.name,
      'industry', i.name,
      'sub_industry', si.name,
      'business_type', coalesce(p.business_type, o.business_type),
      'module_count', (
        select pg_catalog.count(*)
        from public.zenvio_workspace_modules wm
        where wm.organization_id = o.id and wm.enabled
      ),
      'dashboard_layout', p.dashboard_layout,
      'created_at', o.created_at
    ) order by o.created_at desc
  ), '[]'::jsonb)
  into result
  from public.zenvio_organizations o
  left join public.zenvio_industry_catalog i on i.id = o.industry_node_id
  left join public.zenvio_industry_catalog si on si.id = o.sub_industry_node_id
  left join public.zenvio_workspace_profiles p on p.organization_id = o.id;

  return result;
end;
$$;

revoke all on function public.zenvio_industry_platform_overview() from public, anon;
grant execute on function public.zenvio_industry_platform_overview() to authenticated;


commit;
),
  display_name text not null,
  description text not null default '',
  implementation_status text not null default 'planned'
    check (implementation_status in ('implemented','configuration_only','planned')),
  route text,
  updated_at timestamptz not null default now()
);

insert into public.zenvio_module_registry(module_key,display_name,description,implementation_status,route)
values
('mirror','MIRROR','Business digital twin and structured business context.','implemented','/mirror.html'),
('anticipate','ANTICIPATE','Evidence-based signals and risk review.','implemented','/anticipate.html'),
('swarm','SWARM','Controlled specialist plans and approval workflow.','implemented','/swarm.html'),
('blackbox','BLACKBOX','Searchable business memory records.','implemented','/modules.html'),
('what_if','WHAT IF','Scenario arithmetic and comparison.','implemented','/modules.html'),
('evolve','EVOLVE','Improvement tracking and measured outcomes.','implemented','/modules.html'),
('aria','ARIA','Industry-specific AI configuration profile; runtime integration remains in progress.','configuration_only','/intelligence.html'),
('crm','CRM','Workspace CRM integration; verify feature scope before commercial activation.','configuration_only','/admin'),
('analytics','Analytics','Industry-specific analytics configuration; vertical data connectors remain in progress.','configuration_only',null),
('website_studio','Website Studio','Industry website templates and publishing workflow.','planned',null),
('commerce','Commerce','Orders, catalogues and checkout engine.','planned',null),
('inventory','Inventory','Stock and inventory operations.','planned',null),
('booking','Booking','Appointments, rooms and reservations.','planned',null),
('payments','Payments','Payment processing and reconciliation.','planned',null),
('projects','Projects','Vertical project and delivery operations.','planned',null),
('logistics','Logistics','Fleet, shipments and supply chain operations.','planned',null),
('learning','Learning','Courses, enrolments and learner progress.','planned',null),
('3d_experience','3D Experience','Interactive 3D web and product experiences.','planned',null),
('data_fortress','DATA FORTRESS','Backup control metadata only; backup engine not connected.','configuration_only','/backup.html'),
('private_cloud','PRIVATE CLOUD','Google Drive connection milestone only; file workflows not active.','configuration_only','/private-cloud.html')
on conflict (module_key) do update
set display_name = excluded.display_name,
    description = excluded.description,
    implementation_status = excluded.implementation_status,
    route = excluded.route,
    updated_at = now();

alter table public.zenvio_module_registry enable row level security;
revoke all on public.zenvio_module_registry from anon, authenticated;
drop policy if exists zenvio_module_registry_read on public.zenvio_module_registry;
create policy zenvio_module_registry_read on public.zenvio_module_registry
for select to authenticated using (true);
drop policy if exists zenvio_module_registry_super_manage on public.zenvio_module_registry;
create policy zenvio_module_registry_super_manage on public.zenvio_module_registry
for all to authenticated
using (public.zenvio_is_super_admin())
with check (public.zenvio_is_super_admin());
grant select, insert, update, delete on public.zenvio_module_registry to authenticated;

alter table public.zenvio_industry_catalog enable row level security;
alter table public.zenvio_workspace_profiles enable row level security;
alter table public.zenvio_workspace_modules enable row level security;
alter table public.zenvio_industry_suggestions enable row level security;

revoke all on public.zenvio_industry_catalog from anon, authenticated;
revoke all on public.zenvio_workspace_profiles from anon, authenticated;
revoke all on public.zenvio_workspace_modules from anon, authenticated;
revoke all on public.zenvio_industry_suggestions from anon, authenticated;

drop policy if exists zenvio_industry_catalog_read on public.zenvio_industry_catalog;
create policy zenvio_industry_catalog_read
on public.zenvio_industry_catalog
for select to authenticated
using ((is_active and is_published) or public.zenvio_is_super_admin());

drop policy if exists zenvio_industry_catalog_super_insert on public.zenvio_industry_catalog;
create policy zenvio_industry_catalog_super_insert
on public.zenvio_industry_catalog
for insert to authenticated
with check (public.zenvio_is_super_admin());

drop policy if exists zenvio_industry_catalog_super_update on public.zenvio_industry_catalog;
create policy zenvio_industry_catalog_super_update
on public.zenvio_industry_catalog
for update to authenticated
using (public.zenvio_is_super_admin())
with check (public.zenvio_is_super_admin());

drop policy if exists zenvio_industry_catalog_super_delete on public.zenvio_industry_catalog;
create policy zenvio_industry_catalog_super_delete
on public.zenvio_industry_catalog
for delete to authenticated
using (public.zenvio_is_super_admin());

drop policy if exists zenvio_workspace_profiles_member_read on public.zenvio_workspace_profiles;
create policy zenvio_workspace_profiles_member_read
on public.zenvio_workspace_profiles
for select to authenticated
using (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_workspace_profiles_owner_insert on public.zenvio_workspace_profiles;
create policy zenvio_workspace_profiles_owner_insert
on public.zenvio_workspace_profiles
for insert to authenticated
with check (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_workspace_profiles_owner_update on public.zenvio_workspace_profiles;
create policy zenvio_workspace_profiles_owner_update
on public.zenvio_workspace_profiles
for update to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']))
with check (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_workspace_modules_member_read on public.zenvio_workspace_modules;
create policy zenvio_workspace_modules_member_read
on public.zenvio_workspace_modules
for select to authenticated
using (public.zenvio_is_member(organization_id));

drop policy if exists zenvio_workspace_modules_owner_manage on public.zenvio_workspace_modules;
create policy zenvio_workspace_modules_owner_manage
on public.zenvio_workspace_modules
for all to authenticated
using (public.zenvio_has_role(organization_id, array['owner','admin']))
with check (public.zenvio_has_role(organization_id, array['owner','admin']));

drop policy if exists zenvio_industry_suggestions_submit on public.zenvio_industry_suggestions;
create policy zenvio_industry_suggestions_submit
on public.zenvio_industry_suggestions
for insert to authenticated
with check (
  submitted_by = auth.uid()
  and (organization_id is null or public.zenvio_is_member(organization_id))
);

drop policy if exists zenvio_industry_suggestions_owner_read on public.zenvio_industry_suggestions;
create policy zenvio_industry_suggestions_owner_read
on public.zenvio_industry_suggestions
for select to authenticated
using (
  submitted_by = auth.uid()
  or public.zenvio_is_super_admin()
  or (organization_id is not null and public.zenvio_has_role(organization_id, array['owner','admin']))
);

drop policy if exists zenvio_industry_suggestions_super_update on public.zenvio_industry_suggestions;
create policy zenvio_industry_suggestions_super_update
on public.zenvio_industry_suggestions
for update to authenticated
using (public.zenvio_is_super_admin())
with check (public.zenvio_is_super_admin());

grant select on public.zenvio_industry_catalog to authenticated;
grant insert, update, delete on public.zenvio_industry_catalog to authenticated;
grant select, insert, update on public.zenvio_workspace_profiles to authenticated;
grant select, insert, update, delete on public.zenvio_workspace_modules to authenticated;
grant select, insert, update on public.zenvio_industry_suggestions to authenticated;

create or replace function public.zenvio_apply_industry_workspace_defaults()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_industry public.zenvio_industry_catalog%rowtype;
  selected_sub public.zenvio_industry_catalog%rowtype;
  module_name text;
  modules_to_enable text[];
begin
  if new.industry_node_id is not null then
    select * into selected_industry
    from public.zenvio_industry_catalog
    where id = new.industry_node_id and level = 'industry' and is_active and is_published;

    if not found then
      raise exception 'Selected industry is unavailable';
    end if;
  end if;

  if new.sub_industry_node_id is not null then
    select * into selected_sub
    from public.zenvio_industry_catalog
    where id = new.sub_industry_node_id
      and level = 'sub_industry'
      and parent_id = new.industry_node_id
      and is_active and is_published;

    if not found then
      raise exception 'Selected sub-industry does not belong to the selected industry';
    end if;
  end if;

  modules_to_enable := coalesce(selected_sub.default_modules, selected_industry.default_modules,
    array['mirror','anticipate','swarm','blackbox','what_if','evolve','aria','crm','analytics']::text[]);

  insert into public.zenvio_workspace_profiles (
    organization_id, industry_id, sub_industry_id, business_type, aria_profile, dashboard_layout
  )
  values (
    new.id, new.industry_node_id, new.sub_industry_node_id,
    coalesce(nullif(trim(new.business_type), ''), 'General Business'),
    coalesce(selected_sub.aria_profile, selected_industry.aria_profile, '{"tone":"professional","mode":"industry_assistant"}'::jsonb),
    coalesce(selected_sub.dashboard_layout, selected_industry.dashboard_layout, '{"version":1,"layout":"industry_default","widgets":[]}'::jsonb)
  )
  on conflict (organization_id) do update
  set industry_id = excluded.industry_id,
      sub_industry_id = excluded.sub_industry_id,
      business_type = excluded.business_type,
      aria_profile = excluded.aria_profile,
      dashboard_layout = excluded.dashboard_layout,
      updated_at = now();

  foreach module_name in array modules_to_enable loop
    insert into public.zenvio_workspace_modules(organization_id, module_key, enabled, source)
    values (new.id, module_name, true, 'industry_default')
    on conflict (organization_id, module_key) do nothing;
  end loop;

  return new;
end;
$$;

drop trigger if exists zenvio_org_industry_defaults on public.zenvio_organizations;
create trigger zenvio_org_industry_defaults
after insert or update of industry_node_id, sub_industry_node_id, business_type
on public.zenvio_organizations
for each row execute function public.zenvio_apply_industry_workspace_defaults();

create or replace function public.zenvio_submit_industry_suggestion(
  p_organization_id uuid,
  p_parent_node_id uuid,
  p_proposed_level text,
  p_proposed_name text,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare suggestion_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_organization_id is not null
     and not public.zenvio_is_member(p_organization_id) then
    raise exception 'Workspace membership required';
  end if;

  if p_proposed_level not in ('industry','sub_industry') then
    raise exception 'Invalid industry level';
  end if;

  if char_length(trim(coalesce(p_proposed_name, ''))) not between 2 and 140 then
    raise exception 'Enter a valid industry name';
  end if;

  if p_proposed_level = 'industry' and p_parent_node_id is not null then
    raise exception 'A top-level industry cannot have a parent';
  end if;

  if p_proposed_level = 'sub_industry' and not exists (
    select 1 from public.zenvio_industry_catalog
    where id = p_parent_node_id and level = 'industry' and is_active
  ) then
    raise exception 'Select a valid parent industry';
  end if;

  insert into public.zenvio_industry_suggestions(
    organization_id, submitted_by, parent_node_id, proposed_level, proposed_name, reason
  )
  values (
    p_organization_id, auth.uid(), p_parent_node_id, p_proposed_level,
    trim(p_proposed_name), nullif(trim(coalesce(p_reason, '')), '')
  )
  returning id into suggestion_id;

  return suggestion_id;
end;
$$;

revoke all on function public.zenvio_submit_industry_suggestion(uuid, uuid, text, text, text)
from public, anon;
grant execute on function public.zenvio_submit_industry_suggestion(uuid, uuid, text, text, text)
to authenticated;

create or replace function public.zenvio_review_industry_suggestion(
  p_suggestion_id uuid,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  suggestion public.zenvio_industry_suggestions%rowtype;
  new_node_id uuid;
  parent_slug text;
  new_slug text;
begin
  if not public.zenvio_is_super_admin() then
    raise exception 'Super Admin access required';
  end if;

  if p_decision not in ('approve','reject') then
    raise exception 'Decision must be approve or reject';
  end if;

  select * into suggestion
  from public.zenvio_industry_suggestions
  where id = p_suggestion_id and status = 'pending'
  for update;

  if not found then
    raise exception 'Pending suggestion not found';
  end if;

  if p_decision = 'reject' then
    update public.zenvio_industry_suggestions
    set status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now()
    where id = p_suggestion_id;
    return jsonb_build_object('status','rejected');
  end if;

  if suggestion.proposed_level = 'sub_industry' then
    select slug into parent_slug from public.zenvio_industry_catalog
    where id = suggestion.parent_node_id and level = 'industry';
    if parent_slug is null then raise exception 'Parent industry no longer exists'; end if;
    new_slug := parent_slug || '-' || trim(both '-' from regexp_replace(lower(suggestion.proposed_name), '[^a-z0-9]+', '-', 'g'));
  else
    new_slug := trim(both '-' from regexp_replace(lower(suggestion.proposed_name), '[^a-z0-9]+', '-', 'g'));
  end if;

  insert into public.zenvio_industry_catalog(
    parent_id, level, name, slug, description, created_by, sort_order
  )
  values (
    case when suggestion.proposed_level = 'sub_industry' then suggestion.parent_node_id else null end,
    suggestion.proposed_level,
    suggestion.proposed_name,
    new_slug,
    'Added from owner industry suggestion.',
    auth.uid(),
    900
  )
  returning id into new_node_id;

  update public.zenvio_industry_suggestions
  set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_suggestion_id;

  return jsonb_build_object('status','approved','industry_node_id',new_node_id);
end;
$$;

revoke all on function public.zenvio_review_industry_suggestion(uuid, text)
from public, anon;
grant execute on function public.zenvio_review_industry_suggestion(uuid, text)
to authenticated;


-- Industry changes use an explicit request/review workflow; browser updates cannot bypass it.
create table if not exists public.zenvio_industry_change_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.zenvio_organizations(id) on delete cascade,
  requested_by uuid not null references auth.users(id) on delete restrict,
  current_industry_id uuid references public.zenvio_industry_catalog(id) on delete set null,
  current_sub_industry_id uuid references public.zenvio_industry_catalog(id) on delete set null,
  proposed_industry_id uuid not null references public.zenvio_industry_catalog(id) on delete restrict,
  proposed_sub_industry_id uuid not null references public.zenvio_industry_catalog(id) on delete restrict,
  proposed_business_type text not null check (char_length(trim(proposed_business_type)) between 2 and 140),
  reason text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.zenvio_industry_change_requests enable row level security;
revoke all on public.zenvio_industry_change_requests from anon, authenticated;

drop policy if exists zenvio_industry_change_request_read on public.zenvio_industry_change_requests;
create policy zenvio_industry_change_request_read
on public.zenvio_industry_change_requests
for select to authenticated
using (
  public.zenvio_is_super_admin()
  or public.zenvio_has_role(organization_id, array['owner','admin'])
);

grant select on public.zenvio_industry_change_requests to authenticated;

create or replace function public.zenvio_guard_industry_profile_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (
    new.industry_node_id is distinct from old.industry_node_id
    or new.sub_industry_node_id is distinct from old.sub_industry_node_id
    or new.business_type is distinct from old.business_type
  ) and coalesce(current_setting('zenvio.industry_change_approved', true), '') <> 'yes' then
    raise exception 'Industry changes must be submitted for review from the workspace settings';
  end if;
  return new;
end;
$$;

drop trigger if exists zenvio_org_industry_change_guard on public.zenvio_organizations;
create trigger zenvio_org_industry_change_guard
before update of industry_node_id, sub_industry_node_id, business_type
on public.zenvio_organizations
for each row execute function public.zenvio_guard_industry_profile_change();

create or replace function public.zenvio_request_industry_change(
  p_organization_id uuid,
  p_industry_id uuid,
  p_sub_industry_id uuid,
  p_business_type text,
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_org public.zenvio_organizations%rowtype;
  new_request_id uuid;
begin
  if auth.uid() is null or not public.zenvio_has_role(p_organization_id, array['owner','admin']) then
    raise exception 'Workspace owner/admin access required';
  end if;

  select * into current_org
  from public.zenvio_organizations
  where id = p_organization_id
  for update;

  if not found then raise exception 'Workspace not found'; end if;

  if not exists (
    select 1 from public.zenvio_industry_catalog
    where id = p_industry_id and level = 'industry' and is_active and is_published
  ) then raise exception 'Choose a published industry'; end if;

  if not exists (
    select 1 from public.zenvio_industry_catalog
    where id = p_sub_industry_id and parent_id = p_industry_id
      and level = 'sub_industry' and is_active and is_published
  ) then raise exception 'Choose a sub-industry under the selected industry'; end if;

  if char_length(trim(coalesce(p_business_type, ''))) not between 2 and 140 then
    raise exception 'Enter a valid business type';
  end if;

  if exists (
    select 1 from public.zenvio_industry_change_requests
    where organization_id = p_organization_id and status = 'pending'
  ) then raise exception 'A workspace industry change is already awaiting review'; end if;

  insert into public.zenvio_industry_change_requests(
    organization_id, requested_by, current_industry_id, current_sub_industry_id,
    proposed_industry_id, proposed_sub_industry_id, proposed_business_type, reason
  )
  values (
    p_organization_id, auth.uid(), current_org.industry_node_id, current_org.sub_industry_node_id,
    p_industry_id, p_sub_industry_id, trim(p_business_type), nullif(trim(coalesce(p_reason, '')), '')
  )
  returning id into new_request_id;

  return new_request_id;
end;
$$;

create or replace function public.zenvio_review_industry_change(
  p_request_id uuid,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  change_request public.zenvio_industry_change_requests%rowtype;
  target_industry public.zenvio_industry_catalog%rowtype;
  target_sub public.zenvio_industry_catalog%rowtype;
  module_name text;
  next_modules text[];
begin
  if not public.zenvio_is_super_admin() then raise exception 'Super Admin access required'; end if;
  if p_decision not in ('approve','reject') then raise exception 'Decision must be approve or reject'; end if;

  select * into change_request
  from public.zenvio_industry_change_requests
  where id = p_request_id and status = 'pending'
  for update;

  if not found then raise exception 'Pending industry change request not found'; end if;

  if p_decision = 'reject' then
    update public.zenvio_industry_change_requests
    set status = 'rejected', reviewed_by = auth.uid(), reviewed_at = now()
    where id = p_request_id;
    return pg_catalog.jsonb_build_object('status','rejected');
  end if;

  select * into target_industry
  from public.zenvio_industry_catalog
  where id = change_request.proposed_industry_id and level = 'industry'
    and is_active and is_published;
  if not found then raise exception 'Proposed industry is no longer available'; end if;

  select * into target_sub
  from public.zenvio_industry_catalog
  where id = change_request.proposed_sub_industry_id
    and parent_id = target_industry.id and level = 'sub_industry'
    and is_active and is_published;
  if not found then raise exception 'Proposed sub-industry is no longer available'; end if;

  perform pg_catalog.set_config('zenvio.industry_change_approved','yes',true);

  update public.zenvio_organizations
  set industry = target_industry.name || ' / ' || target_sub.name,
      industry_node_id = target_industry.id,
      sub_industry_node_id = target_sub.id,
      business_type = change_request.proposed_business_type
  where id = change_request.organization_id;

  next_modules := target_sub.default_modules;

  update public.zenvio_workspace_modules
  set enabled = false, source = 'owner_disabled', updated_at = now()
  where organization_id = change_request.organization_id
    and source = 'industry_default'
    and not (module_key = any(next_modules));

  foreach module_name in array next_modules loop
    insert into public.zenvio_workspace_modules(organization_id, module_key, enabled, source)
    values (change_request.organization_id, module_name, true, 'industry_default')
    on conflict (organization_id, module_key) do nothing;
  end loop;

  update public.zenvio_industry_change_requests
  set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_request_id;

  return pg_catalog.jsonb_build_object('status','approved','organization_id',change_request.organization_id);
end;
$$;

revoke all on function public.zenvio_request_industry_change(uuid, uuid, uuid, text, text) from public, anon;
revoke all on function public.zenvio_review_industry_change(uuid, text) from public, anon;
grant execute on function public.zenvio_request_industry_change(uuid, uuid, uuid, text, text) to authenticated;
grant execute on function public.zenvio_review_industry_change(uuid, text) to authenticated;

commit;
